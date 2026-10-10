class LunchMenu < ApplicationRecord
  GROUPS = { 'soup' => 'Sopa', 'plate' => 'Prato', 'drink' => 'Bebida', 'coffee' => 'Café' }.freeze
  DAYS = [['Seg', 1], ['Ter', 2], ['Qua', 3], ['Qui', 4], ['Sex', 5], ['Sáb', 6], ['Dom', 0]].freeze
  belongs_to :establishment
  include BroadcastsCustomerMenu
  validates :menu_kind, inclusion: { in: %w[lunch breakfast] }, uniqueness: { scope: :establishment_id }
  validates :title, length: { maximum: 80 }
  validates :starts_at, :ends_at, presence: true
  validates :combo_price, numericality: { greater_than_or_equal_to: 0, less_than: 100000 }
  validate :configuration_is_valid

  def self.for_management(venue, kind)
    kind = kind == 'breakfast' ? 'breakfast' : 'lunch'
    menu = venue.scheduled_menus.find_or_initialize_by(menu_kind: kind)
    return menu unless menu.new_record?
    defaults = if kind == 'breakfast'
      [['coffee', 'Bebida quente', ['coffee']], ['bread', 'Pão ou pastelaria', %w[snack dessert]], ['drink', 'Bebida', ['drink']]]
    else
      [['soup', 'Sopa', ['soup']], ['plate', 'Prato', %w[plate snack]], ['coffee', 'Café', ['coffee']]]
    end
    defaults << ['dessert', 'Sobremesa', ['dessert']]
    menu.group_definitions = defaults.map { |key,name,types| { 'key' => key, 'name' => name, 'types' => types, 'optional' => false } }
    menu.groups_configured = true
    menu.individual_enabled = false
    menu.combo_enabled = true
    if kind == 'breakfast'
      menu.starts_at = '08:00'; menu.ends_at = '11:30'; menu.combo_price = 5
    end
    menu
  end

  def display_title
    title.presence || (menu_kind == 'breakfast' ? 'Pequeno-almoço' : 'Almoço')
  end

  def groups
    return group_definitions if groups_configured? || group_definitions.present?
    if menu_kind == 'breakfast'
      [{ 'key' => 'coffee', 'name' => 'Bebida quente', 'types' => ['coffee'], 'optional' => false },
       { 'key' => 'bread', 'name' => 'Pão ou pastelaria', 'types' => %w[snack dessert], 'optional' => false },
       { 'key' => 'drink', 'name' => 'Sumo / bebida', 'types' => ['drink'], 'optional' => true }]
    else
      GROUPS.map { |key, name| { 'key' => key, 'name' => name, 'types' => key == 'plate' ? %w[plate snack] : [key], 'optional' => key == 'coffee' } }
    end
  end

  def product_matches?(item, group)
    Array(group['types']).include?(item.product_kind) || (!groups_configured? && group_definitions.empty? && persisted? && item.product_kind == 'unclassified')
  end

  def open?(at: Time.current)
    local = at.in_time_zone('Lisbon')
    active? && Array(weekdays).include?(local.wday) && local >= boundary(local.to_date, starts_at) && local < boundary(local.to_date, ends_at)
  end

  def next_transition_at(at: Time.current)
    return unless active? && starts_at && ends_at
    local = at.in_time_zone('Lisbon')
    (0..7).flat_map do |offset|
      date = local.to_date + offset
      Array(weekdays).include?(date.wday) ? [boundary(date, starts_at), boundary(date, ends_at)] : []
    end.select { |time| time > at }.min
  end

  def products
    @products ||= establishment.menu_items.not_archived.includes(:category).index_by(&:id)
  end

  def available_product(id)
    item = products[id.to_i]
    item if item&.available? && item.category.visible_to_customers?
  end

  def available_individual_offers
    return [] unless individual_enabled?
    Array(individual_offers).filter_map do |offer|
      item = available_product(offer['menu_item_id'])
      { item: item, price: BigDecimal(offer['price']) } if item
    end
  end

  def available_groups
    groups.map do |group|
      key, name = group.values_at('key', 'name')
      options = Array(combo_groups[key]).filter_map do |option|
        item = available_product(option['menu_item_id'])
        { item: item, supplement: BigDecimal(option['supplement']), id: item.id } if item && product_matches?(item, group)
      end
      { key: key, name: name, optional: group['optional'] == true, options: options }
    end
  end

  def combo_available?
    required = available_groups.reject { |group| group[:optional] }
    combo_enabled? && required.any? && required.all? { |group| group[:options].any? }
  end

  def selection(kind:, quantity:, menu_item_id: nil, choices: {})
    raise Order::InvalidTransition, 'O menu de almoço já não está disponível neste horário.' unless open?
    quantity = Integer(quantity, exception: false)
    raise Order::InvalidTransition, 'Quantidade inválida.' unless quantity && (1..99).cover?(quantity)
    metadata = { 'kind' => kind, 'lunch_menu_id' => id, 'version' => updated_at.iso8601(6) }
    if kind == 'individual'
      offer = available_individual_offers.find { |row| row[:item].id == menu_item_id.to_i }
      raise Order::InvalidTransition, 'Este prato do dia já não está disponível.' unless offer
      item, price = offer.values_at(:item, :price)
      { menu_item_id: item.id, name: item.name, quantity: quantity, unit_price: price, line_total: price * quantity, lunch_selection: metadata }
    elsif kind == 'combo'
      raise Order::InvalidTransition, 'O menu completo já não está disponível.' unless combo_available?
      price = combo_price
      selected = available_groups.map do |group|
        choice_id = choices[group[:key]].to_s
        if group[:optional] && choice_id.blank?
          { 'group' => group[:key], 'label' => group[:name], 'menu_item_id' => nil, 'name' => "Sem #{group[:name].downcase}", 'supplement' => '0' }
        else
          option = group[:options].find { |row| row[:id].to_s == choice_id }
          raise Order::InvalidTransition, "Escolhe uma opção disponível para #{group[:name].downcase}." unless option
          price += option[:supplement]
          { 'group' => group[:key], 'label' => group[:name], 'menu_item_id' => option[:id], 'name' => option[:item].name, 'supplement' => option[:supplement].to_s('F') }
        end
      end
      raise Order::InvalidTransition, 'Preço do menu inválido.' if price >= 100000
      { menu_item_id: nil, name: (menu_kind == 'lunch' ? 'Menu completo' : "#{display_title} · Menu completo"), quantity: quantity, unit_price: price, line_total: price * quantity,
        lunch_selection: metadata.merge('choices' => selected) }
    else
      raise Order::InvalidTransition, 'Opção de almoço inválida.'
    end
  end

  def self.validated_selection(establishment, metadata, item_id, quantity, price)
    metadata = metadata.stringify_keys
    menu = establishment.scheduled_menus.find_by(id: metadata['lunch_menu_id'])
    unless menu && menu.id == metadata['lunch_menu_id'].to_i && menu.updated_at.iso8601(6) == metadata['version']
      raise Order::InvalidTransition, 'O menu de almoço mudou. Reveja o pedido.'
    end
    choices = Array(metadata['choices']).to_h { |choice| choice = choice.stringify_keys; [choice['group'], choice['menu_item_id']] }
    row = menu.selection(kind: metadata['kind'], quantity: quantity, menu_item_id: item_id, choices: choices)
    raise Order::InvalidTransition, 'O preço do almoço mudou. Reveja o pedido.' unless row[:unit_price] == BigDecimal(price.to_s)
    row
  end

  private

  def boundary(date, time)
    ActiveSupport::TimeZone['Lisbon'].local(date.year, date.month, date.day, time.hour, time.min)
  end

  def valid_money?(value)
    number = BigDecimal(value.to_s, exception: false)
    number && number >= 0 && number < 100000 && number == number.round(2)
  end

  def configuration_is_valid
    unless weekdays.is_a?(Array) && weekdays.any? && weekdays.all? { |day| day.is_a?(Integer) && (0..6).cover?(day) }
      errors.add(:weekdays, 'seleciona pelo menos um dia válido')
    end
    errors.add(:ends_at, 'deve ser posterior ao início') if starts_at && ends_at && ends_at <= starts_at
    errors.add(:combo_price, 'deve ter no máximo duas casas decimais') if !valid_money?(combo_price_before_type_cast)
    unless individual_offers.is_a?(Array) && combo_groups.is_a?(Hash)
      errors.add(:base, 'Configuração de almoço inválida.')
      return
    end
    unless group_definitions.is_a?(Array) && group_definitions.size <= 8 && group_definitions.all? { |g| g.is_a?(Hash) && g['key'].to_s.match?(/\A[a-z][a-z0-9_]{0,30}\z/) && g['name'].to_s.length.between?(1,60) && g['types'].is_a?(Array) && g['types'].any? && (g['types'] - MenuItem::PRODUCT_KINDS.keys).empty? && [true,false].include?(g['optional']) } && groups.map { |g| g['key'] }.uniq.size == groups.size
      errors.add(:base, 'Grupos de escolhas inválidos.')
      return
    end
    rows = individual_offers + combo_groups.values.flat_map { |options| options.is_a?(Array) ? options : [nil] }
    valid_ids = establishment&.menu_items&.not_archived&.pluck(:id) || []
    valid = rows.size <= 1000 && rows.all? do |row|
      row.is_a?(Hash) && valid_ids.include?(row['menu_item_id'].to_i) && valid_money?(row.key?('price') ? row['price'] : row['supplement'])
    end
    errors.add(:base, 'Escolhe produtos deste estabelecimento e preços válidos.') unless valid
    return unless valid
    errors.add(:base, 'Grupos de menu inválidos.') unless (combo_groups.keys - groups.map { |g| g['key'] }).empty?
    if group_definitions.present?
      groups.each do |group|
        Array(combo_groups[group['key']]).each do |row|
          item = establishment.menu_items.find_by(id: row['menu_item_id'])
          errors.add(:base, "#{item&.name}: classifica o produto no tipo correto para #{group['name']}.") if item && !product_matches?(item, group)
        end
      end
    end
    return unless active?
    errors.add(:base, 'Ativa pratos avulso ou o menu completo.') unless individual_enabled? || combo_enabled?
    errors.add(:base, 'Seleciona pelo menos um prato avulso.') if individual_enabled? && individual_offers.empty?
    if combo_enabled? && groups.reject { |g| g['optional'] }.any? { |g| Array(combo_groups[g['key']]).empty? }
      errors.add(:base, 'Seleciona produtos em todos os grupos obrigatórios do menu completo.')
    end
    errors.add(:base, 'Escolhe pelo menos um grupo para o menu completo.') if combo_enabled? && groups.all? { |g| g['optional'] }
  end
end
