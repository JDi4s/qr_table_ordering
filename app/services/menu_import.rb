require 'digest'

class MenuImport
  class Invalid < StandardError; end
  PRODUCT_FIELDS = %w[name description price available normal_menu_visible product_kind preparation_key allergens allergen_notes nutrition_enabled nutrition_basis nutrition_portion].concat(MenuItem::NUTRITION_FIELDS.keys.map { |key| "nutrition_#{key}" }).freeze
  LUNCH_FIELDS = %w[menu_kind title group_definitions weekdays starts_at ends_at combo_price].freeze
  attr_reader :source, :destination, :categories, :products, :selected_categories, :selected_products

  def initialize(source:, destination:, category_ids: nil, product_ids: nil)
    @source, @destination = source, destination
    raise Invalid, 'Escolhe outro estabelecimento de origem.' if source.id == destination.id
    raise Invalid, 'Este estabelecimento já tem menu. A importação só está disponível para menus vazios.' unless destination.menu_empty?
    scope = source.categories.order(:name)
    scope = scope.lock if ActiveRecord::Base.connection.transaction_open?
    all_categories = scope.to_a
    by_id = all_categories.index_by(&:id)
    @categories = all_categories.select do |category|
      node, seen = category, []
      eligible = true
      while node
        if node.archived? || seen.include?(node.id)
          eligible = false
          break
        end
        seen << node.id
        node = by_id[node.parent_id]
      end
      eligible
    end
    item_scope = source.menu_items.not_archived.where(category_id: categories.map(&:id)).includes(:production_area, image_attachment: :blob).order(:name)
    item_scope = item_scope.lock if ActiveRecord::Base.connection.transaction_open?
    @products = item_scope.to_a
    category_ids = category_ids.nil? ? categories.map(&:id) : parse_ids(category_ids)
    product_ids = product_ids.nil? ? products.map(&:id) : parse_ids(product_ids)
    raise Invalid, 'O menu de origem mudou. Escolhe novamente os produtos.' unless (category_ids - categories.map(&:id)).empty? && (product_ids - products.map(&:id)).empty?
    @selected_products = products.select { |item| product_ids.include?(item.id) }
    # Product selections always retain their category and its ancestors.
    required_ids = category_ids | selected_products.map(&:category_id)
    required_ids.dup.each do |id|
      node = by_id[id]
      while node&.parent_id
        required_ids |= [node.parent_id]
        node = by_id[node.parent_id]
      end
    end
    @selected_categories = categories.select { |category| required_ids.include?(category.id) }
  end

  def counts
    { categories: selected_categories.size, products: selected_products.size,
      photos: selected_products.count { |product| product.image.attached? },
      suggestions: recommendations.size, lunch: lunch_attributes.present? }
  end

  def digest
    payload = { source: source.id, destination: destination.id,
      categories: selected_categories.map { |c| c.attributes.slice('id', 'name', 'parent_id', 'available') },
      products: selected_products.map { |p| p.attributes.slice('id', 'category_id', 'production_area_id', *PRODUCT_FIELDS).merge('photo' => p.image.blob&.id) },
      recommendations: recommendations.map { |r| [r.menu_item_id, r.recommended_menu_item_id] },
      lunch: scheduled_attributes, areas: destination.available_production_areas.pluck(:id, :name), limit: destination.production_areas_limit }
    Digest::SHA256.hexdigest(canonical(payload.as_json).to_json)
  end

  def scheduled_attributes
    return @scheduled_attributes if defined?(@scheduled_attributes)
    ids = selected_products.map(&:id)
    @scheduled_attributes = source.scheduled_menus.order(:menu_kind).filter_map do |menu|
      offers = menu.individual_offers.select { |row| ids.include?(row['menu_item_id'].to_i) }
      groups = menu.groups.to_h { |group| [group['key'], Array(menu.combo_groups[group['key']]).select { |row| ids.include?(row['menu_item_id'].to_i) }] }
      next if offers.empty? && groups.values.all?(&:empty?)
      individual = menu.individual_enabled? && offers.any?
      combo = menu.combo_enabled? && menu.groups.reject { |g| g['optional'] }.all? { |g| groups[g['key']].any? }
      menu.attributes.slice(*LUNCH_FIELDS).merge('individual_offers' => offers, 'combo_groups' => groups,
        'individual_enabled' => individual, 'combo_enabled' => combo, 'active' => menu.active? && (individual || combo))
    end
  end

  def lunch_attributes
    scheduled_attributes.find { |attributes| attributes['menu_kind'] == 'lunch' } || scheduled_attributes.first
  end

  def incomplete_lunch?
    source.scheduled_menus.any? { |menu| menu.combo_enabled? && scheduled_attributes.any? { |a| a['menu_kind'] == menu.menu_kind && !a['combo_enabled'] } }
  end

  def unassigned_areas
    names = destination.available_production_areas.map { |area| area.name.downcase }
    selected_products.count { |item| item.production_area && !names.include?(item.production_area.name.downcase) }
  end

  def self.copy!(source_id:, destination_id:, category_ids:, product_ids:, expected_digest:, user:)
    destination = Establishment.find(destination_id)
    result = nil
    CustomerMenuBroadcast.batch do
      Establishment.transaction do
        venues = Establishment.where(id: [source_id, destination_id]).order(:id).lock.index_by(&:id)
        source, destination = venues.values_at(source_id.to_i, destination_id.to_i)
        raise Invalid, 'Estabelecimento não encontrado.' unless source && destination
        plan = new(source: source, destination: destination, category_ids: category_ids, product_ids: product_ids)
        raise Invalid, 'Seleciona pelo menos uma categoria ou produto.' if plan.selected_categories.empty?
        raise Invalid, 'O menu mudou desde a revisão. Revê a seleção antes de importar.' unless ActiveSupport::SecurityUtils.secure_compare(plan.digest, expected_digest.to_s)
        category_map, product_map = {}, {}
        remaining = plan.selected_categories.dup
        until remaining.empty?
          ready, remaining = remaining.partition { |category| category.parent_id.nil? || category_map.key?(category.parent_id) }
          raise Invalid, 'A estrutura de categorias não é válida.' if ready.empty?
          ready.each do |category|
            category_map[category.id] = destination.categories.create!(name: category.name, available: category.available?, parent: category_map[category.parent_id])
          end
        end
        areas = destination.available_production_areas.index_by { |area| area.name.downcase }
        plan.selected_products.each do |product|
          copy = category_map.fetch(product.category_id).menu_items.create!(product.attributes.slice(*PRODUCT_FIELDS).merge(production_area: areas[product.production_area&.name&.downcase]))
          copy.image.attach(product.image.blob) if product.image.attached?
          product_map[product.id] = copy
        end
        plan.send(:recommendations).each do |recommendation|
          product_map.fetch(recommendation.menu_item_id).recommendations.create!(recommended_menu_item: product_map.fetch(recommendation.recommended_menu_item_id))
        end
        plan.scheduled_attributes.each do |attributes|
          attributes = attributes.deep_dup
          attributes['individual_offers'].each { |row| row['menu_item_id'] = product_map.fetch(row['menu_item_id'].to_i).id }
          attributes['combo_groups'].each_value { |rows| rows.each { |row| row['menu_item_id'] = product_map.fetch(row['menu_item_id'].to_i).id } }
          destination.scheduled_menus.create!(attributes)
        end
        result = plan.counts
        AuditEvent.create!(establishment: destination, user: user, action: 'menu_imported', auditable: destination,
          metadata: result.merge(source_establishment_id: source.id, source_establishment_name: source.name))
      end
    end
    result
  rescue ActiveRecord::RecordInvalid => error
    raise Invalid, error.record.errors.full_messages.join('. ')
  end

  private

  def canonical(value)
    case value
    when Hash then value.sort.to_h.transform_values { |item| canonical(item) }
    when Array then value.map { |item| canonical(item) }
    else value
    end
  end

  def parse_ids(values)
    raise Invalid, 'Seleção inválida.' unless values.is_a?(Array) && values.size <= 5000
    values.reject(&:blank?).map { |id| Integer(id, exception: false) || raise(Invalid, 'Seleção inválida.') }.uniq
  end

  def recommendations
    @recommendations ||= MenuItemRecommendation.where(menu_item_id: selected_products.map(&:id), recommended_menu_item_id: selected_products.map(&:id)).order(:id).to_a
  end
end
