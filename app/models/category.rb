class Category < ApplicationRecord
  belongs_to :establishment
  belongs_to :parent, class_name: 'Category', optional: true

  has_many :children,
    class_name: 'Category',
    foreign_key: :parent_id,
    inverse_of: :parent,
    dependent: :restrict_with_error

  has_many :menu_items, dependent: :restrict_with_error

  scope :not_archived, -> { where(archived_at: nil) }

  attribute :available, :boolean, default: true

  validates :name, presence: true, length: { maximum: 120 }

  validate :parent_belongs_to_same_establishment
  validate :parent_cannot_create_cycle

  def root?
    parent_id.nil?
  end

  def visible_to_customers?
    !archived? && available? && (parent.nil? || parent.visible_to_customers?)
  end

  def archived?
    archived_at.present?
  end

  private

  def parent_belongs_to_same_establishment
    return if parent.blank? || establishment.blank?
    return if parent.establishment_id == establishment_id

    errors.add(:parent_id, 'tem de pertencer ao mesmo estabelecimento')
  end

  def parent_cannot_create_cycle
    return if parent.blank?

    ancestor = parent
    visited_ids = []

    while ancestor
      if ancestor == self || visited_ids.include?(ancestor.id)
        errors.add(:parent_id, 'não pode criar um ciclo de categorias')
        break
      end

      visited_ids << ancestor.id
      ancestor = ancestor.parent
    end
  end
end
