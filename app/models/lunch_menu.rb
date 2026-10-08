class LunchMenu < ApplicationRecord
  GROUPS = { 'soup' => 'Sopa', 'plate' => 'Prato', 'drink' => 'Bebida', 'coffee' => 'Café' }.freeze
  DAYS = [['Seg', 1], ['Ter', 2], ['Qua', 3], ['Qui', 4], ['Sex', 5], ['Sáb', 6], ['Dom', 0]].freeze
  belongs_to :establishment
  include BroadcastsCustomerMenu
  validates :establishment_id, uniqueness: true
  validates :starts_at, :ends_at, presence: true
  validates :combo_price, numericality: { greater_than_or_equal_to: 0, less_than: 100000 }
  validate :configuration_is_valid

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
    GROUPS.map do |key, name|
      options = Array(combo_groups[key]).filter_map do |option|
        item = available_product(option['menu_item_id'])
        { item: item, supplement: BigDecimal(option['supplement']), id: item.id } if item
      end
      { key: key, name: name, optional: key == 'coffee', options: options }
    end
  end

  def combo_available?
    combo_enabled? && available_groups.reject { |group| group[:optional] }.all? { |group| group[:options].any? }
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
          { 'group' => group[:key], 'label' => group[:name], 'menu_item_id' => nil, 'name' => 'Sem café', 'supplement' => '0' }
        else
          option = group[:options].find { |row| row[:id].to_s == choice_id }
          raise Order::InvalidTransition, "Escolhe uma opção disponível para #{group[:name].downcase}." unless option
          price += option[:supplement]
          { 'group' => group[:key], 'label' => group[:name], 'menu_item_id' => option[:id], 'name' => option[:item].name, 'supplement' => option[:supplement].to_s('F') }
        end
      end
      raise Order::InvalidTransition, 'Preço do menu inválido.' if price >= 100000
      { menu_item_id: nil, name: 'Menu completo', quantity: quantity, unit_price: price, line_total: price * quantity,
        lunch_selection: metadata.merge('choices' => selected) }
    else
      raise Order::InvalidTransition, 'Opção de almoço inválida.'
    end
  end

  def self.validated_selection(establishment, metadata, item_id, quantity, price)
    metadata = metadata.stringify_keys
    menu = establishment.lunch_menu
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
    rows = individual_offers + combo_groups.values.flat_map { |options| options.is_a?(Array) ? options : [nil] }
    valid_ids = establishment&.menu_items&.not_archived&.pluck(:id) || []
    valid = rows.size <= 1000 && rows.all? do |row|
      row.is_a?(Hash) && valid_ids.include?(row['menu_item_id'].to_i) && valid_money?(row.key?('price') ? row['price'] : row['supplement'])
    end
    errors.add(:base, 'Escolhe produtos deste estabelecimento e preços válidos.') unless valid
    errors.add(:base, 'Grupos de menu inválidos.') unless (combo_groups.keys - GROUPS.keys).empty?
    return unless active?
    errors.add(:base, 'Ativa pratos avulso ou o menu completo.') unless individual_enabled? || combo_enabled?
    errors.add(:base, 'Seleciona pelo menos um prato avulso.') if individual_enabled? && individual_offers.empty?
    if combo_enabled? && %w[soup plate drink].any? { |key| Array(combo_groups[key]).empty? }
      errors.add(:base, 'O menu completo precisa de sopa, prato e bebida.')
    end
  end
end
