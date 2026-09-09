class MenuItemRecommendation < ApplicationRecord
  belongs_to :menu_item
  belongs_to :recommended_menu_item, class_name: 'MenuItem'

  validate :same_establishment
  validate :not_self

  private

  def same_establishment
    return unless menu_item&.establishment && recommended_menu_item&.establishment
    return if menu_item.establishment.id == recommended_menu_item.establishment.id

    errors.add(:recommended_menu_item, 'tem de pertencer ao mesmo estabelecimento')
  end

  def not_self
    errors.add(:recommended_menu_item, 'não pode ser o próprio produto') if menu_item_id == recommended_menu_item_id
  end
end
