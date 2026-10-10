class MenuItem < ApplicationRecord
  PRODUCT_KINDS = { 'unclassified' => 'Por classificar', 'soup' => 'Sopa', 'plate' => 'Prato', 'snack' => 'Snack / sandes', 'dessert' => 'Sobremesa', 'drink' => 'Bebida', 'coffee' => 'Café / bebida quente' }.freeze
  PREPARATION_KEYS = { 'counter' => 'Balcão', 'kitchen' => 'Cozinha', 'snacks' => 'Cozinha de snacks' }.freeze
  scope :normal_menu, -> { where(normal_menu_visible: true) }
  scope :needing_classification, ->(venue) {
    missing = not_archived.where(product_kind: 'unclassified')
    if venue.service_division_enabled?
      missing = missing.or(not_archived.where(production_area_id: nil))
      missing = missing.or(not_archived.where.not(production_area_id: venue.available_production_areas.select(:id)))
    end
    missing
  }
  validates :product_kind, inclusion: { in: PRODUCT_KINDS.keys }
  validates :preparation_key, inclusion: { in: PREPARATION_KEYS.keys }
  validate do
    errors.add(:production_area, 'não pertence ao estabelecimento') if production_area && production_area.establishment_id != category&.establishment_id
  end

  def menu_labels
    labels = normal_menu_visible? ? ['Carta'] : []
    labels << 'Diárias / Brunch' if scheduled_menu_visible?
    establishment.scheduled_menus.each do |menu|
      ids = menu.individual_offers.map { |o| o['menu_item_id'].to_i } + menu.combo_groups.values.flatten.map { |o| o['menu_item_id'].to_i }
      labels << menu.display_title if ids.include?(id)
    end
    labels.presence || ['Sem menu atribuído']
  end

  ALLERGENS = {
    'gluten' => 'Glúten', 'milk' => 'Leite', 'eggs' => 'Ovos', 'nuts' => 'Frutos de casca rija',
    'soy' => 'Soja', 'peanuts' => 'Amendoim', 'fish' => 'Peixe', 'crustaceans' => 'Crustáceos',
    'molluscs' => 'Moluscos', 'celery' => 'Aipo', 'mustard' => 'Mostarda', 'sesame' => 'Sésamo',
    'sulphites' => 'Sulfitos', 'lupin' => 'Tremoço'
  }.freeze
  NUTRITION_FIELDS = {
    'energy' => ['Energia', 'kcal'], 'fat' => ['Gorduras', 'g'], 'saturated' => ['Saturadas', 'g'],
    'carbs' => ['Hidratos', 'g'], 'sugar' => ['Açúcares', 'g'], 'protein' => ['Proteínas', 'g'],
    'fibre' => ['Fibra', 'g'], 'salt' => ['Sal', 'g']
  }.freeze
  belongs_to :category
  belongs_to :production_area, optional: true
  has_one :establishment, through: :category
  has_one_attached :image
  include BroadcastsCustomerMenu
  has_many :order_items, dependent: :nullify
  has_many :orders, through: :order_items
  has_many :recommendations, class_name: 'MenuItemRecommendation', dependent: :destroy
  has_many :recommended_menu_items, through: :recommendations
  has_many :recommended_by, class_name: 'MenuItemRecommendation',
           foreign_key: :recommended_menu_item_id, dependent: :destroy
  has_many :recommended_by_menu_items, through: :recommended_by, source: :menu_item
  before_destroy :prevent_deletion_during_ongoing_order, prepend: true

  scope :not_archived, -> { where(archived_at: nil) }

  attribute :available, :boolean, default: true
  validate { errors.add(:price, 'deve ter no máximo duas casas decimais') if price && price != price.round(2) }
  validates :name, presence: true, length: { maximum: 150 }
  validates :description, length: { maximum: 500 }, allow_blank: true
  validates :price, numericality: { greater_than_or_equal_to: 0, less_than: 100000 }
  before_validation :normalize_product_information
  validates :allergen_notes, length: { maximum: 500 }, allow_blank: true
  validates :nutrition_portion, length: { maximum: 100 }, allow_blank: true
  validates :nutrition_portion, presence: true, if: -> { nutrition_enabled? && nutrition_basis == 'portion' }
  validates :nutrition_basis, inclusion: { in: %w[100g 100ml portion] }
  validates(*NUTRITION_FIELDS.keys.map { |field| "nutrition_#{field}" },
            numericality: { greater_than_or_equal_to: 0, less_than: 100000 }, allow_nil: true)
  validate :allergens_must_be_known

  def allergen_labels
    ALLERGENS.filter_map { |key, label| label if Array(allergens).include?(key) }
  end

  def nutrition_rows
    return [] unless nutrition_enabled?
    NUTRITION_FIELDS.filter_map do |field, (label, unit)|
      value = public_send("nutrition_#{field}")
      [label, value, unit] unless value.nil?
    end
  end

  def nutrition_basis_label
    { '100g' => 'Por 100 g', '100ml' => 'Por 100 ml', 'portion' => "Por porção · #{nutrition_portion}" }.fetch(nutrition_basis)
  end

  def product_information?
    description.present? || allergen_labels.any? || allergen_notes.present? || nutrition_rows.any?
  end

  def archived?
    archived_at.present?
  end

  def used_by_ongoing_order?
    order_items
      .joins(:order)
      .merge(Order.not_voided)
      .where.not(orders: { status: %w[served denied] })
      .exists?
  end

  private

  def normalize_product_information
    self.allergens = allergens.reject(&:blank?).uniq if allergens.is_a?(Array)
    self.allergen_notes = allergen_notes.to_s.strip.presence
    self.nutrition_portion = nutrition_portion.to_s.strip.presence
  end

  def allergens_must_be_known
    unless allergens.is_a?(Array) && (allergens - ALLERGENS.keys).empty?
      errors.add(:allergens, 'contêm uma opção inválida')
    end
  end

  def prevent_deletion_during_ongoing_order
    return unless used_by_ongoing_order?

    raise Order::InvalidTransition, 'Este produto está num pedido em curso. Conclua ou anule primeiro o pedido.'
  end

end
