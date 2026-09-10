require 'test_helper'

class MenuSuggestionEngineTest < ActiveSupport::TestCase
  setup do
    @establishment = Establishment.create!(name: 'Café Sugestões', slug: "cafe-sugestoes-#{SecureRandom.hex(4)}")
    beverages = @establishment.categories.create!(name: 'Bebidas')
    @coffee_category = beverages.children.create!(name: 'Cafetaria', establishment: @establishment)
    food = @establishment.categories.create!(name: 'Comidas')
    @pastry_category = food.children.create!(name: 'Pastelaria', establishment: @establishment)
    @beer_category = beverages.children.create!(name: 'Cerveja', establishment: @establishment)
  end

  test 'suggests pastry for coffee and does not suggest spirits' do
    coffee = @coffee_category.menu_items.create!(name: 'Café', price: 1.50)
    nata = @pastry_category.menu_items.create!(name: 'Pastel de nata', price: 1.50)
    aguardente = @beer_category.menu_items.create!(name: 'Aguardente', price: 2.50)

    suggestions = MenuSuggestionEngine.call(
      source_items: [coffee],
      scope: @establishment.menu_items.where(available: true),
      limit: 4
    )

    assert_includes suggestions, nata
    assert_not_includes suggestions, aguardente
  end
end
