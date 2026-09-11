class MenuItem < ApplicationRecord
  belongs_to :category
  belongs_to :production_area, optional: true
  has_one :establishment, through: :category
  has_one_attached :image
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

  def prevent_deletion_during_ongoing_order
    return unless used_by_ongoing_order?

    raise Order::InvalidTransition, 'Este produto está num pedido em curso. Conclua ou anule primeiro o pedido.'
  end

end
