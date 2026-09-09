require 'test_helper'

class MenuItemRecommendationTest < ActiveSupport::TestCase
  test 'only links products from the same establishment and never itself' do
    venue, = build_venue
    category = venue.categories.first
    coffee = category.menu_items.create!(name: 'Café', price: 1.2, available: true)
    nata = category.menu_items.create!(name: 'Nata', price: 1.5, available: true)

    recommendation = MenuItemRecommendation.new(menu_item: coffee, recommended_menu_item: nata)
    assert_predicate recommendation, :valid?

    recommendation = MenuItemRecommendation.new(menu_item: coffee, recommended_menu_item: coffee)
    assert_not recommendation.valid?
  end
end
