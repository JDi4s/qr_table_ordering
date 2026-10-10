require 'test_helper'
class MenuVisionTest < ActionDispatch::IntegrationTest
  setup do
    @venue, _, @product = build_venue
    @product.update!(product_kind: 'soup', scheduled_menu_visible: true)
    sign_in venue_user(@venue)
  end
  test 'creating in brunch assigns only brunch and a compatible group' do
    post staff_menu_items_path, params: { menu_section: 'scheduled', menu_kind: 'breakfast', scheduled_group: 'coffee', menu_item: { name: 'Cappuccino', category_id: @product.category_id, product_kind: 'coffee', price: 2, available: '1' } }
    assert_response :see_other
    coffee = @venue.menu_items.find_by!(name: 'Cappuccino')
    menu = @venue.scheduled_menus.find_by!(menu_kind: 'breakfast')
    assert_equal coffee.id, menu.individual_offers.first['menu_item_id']
    assert_equal coffee.id, menu.combo_groups['coffee'].first['menu_item_id']
    assert_not coffee.normal_menu_visible?
    assert_nil @venue.scheduled_menus.find_by(menu_kind: 'lunch')
  end
  test 'scheduled price does not change carta price and invalid group rolls back creation' do
    ScheduledMenuProducts.add!(@venue, @product, kind: 'lunch', price: 3)
    assert_equal %w[soup plate coffee dessert], @venue.scheduled_menus.find_by!(menu_kind: 'lunch').groups.map { |g| g['key'] }
    original = @product.price
    patch staff_menu_item_path(@product), params: { menu_section: 'scheduled', menu_kind: 'lunch', menu_item: { name: @product.name, category_id: @product.category_id, product_kind: 'soup', price: 4 } }
    assert_response :see_other
    assert_equal original, @product.reload.price
    assert_equal BigDecimal('4'), BigDecimal(@venue.scheduled_menus.find_by!(menu_kind: 'lunch').individual_offers.first['price'])
    assert_no_difference('MenuItem.count') do
      post staff_menu_items_path, params: { menu_section: 'scheduled', scheduled_group: 'coffee', menu_item: { name: 'Sopa no grupo errado', category_id: @product.category_id, product_kind: 'soup', price: 2 } }
    end
    assert_response :unprocessable_entity
  end
  test 'menu selection shows assigned products in their groups' do
    ScheduledMenuProducts.add!(@venue, @product, kind: 'lunch', group_key: 'soup', price: 3)
    get staff_menu_path(menu_section: 'scheduled', menu_kind: 'lunch')
    assert_select '.menu-production-group .menu-product-info strong', text: @product.name
    assert_select '.menu-product-price', text: /3,00/
    get staff_menu_path(menu_section: 'scheduled', menu_kind: 'breakfast')
    assert_select '.menu-group-grid .menu-product-info strong', text: @product.name, count: 0
    assert_select '.menu-pending-products .menu-product-info strong', text: @product.name
  end
end
