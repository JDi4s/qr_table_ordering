require 'test_helper'
class MenuMembershipTest < ActionDispatch::IntegrationTest
  setup do
    @venue, _, @product = build_venue
    sign_in venue_user(@venue)
  end

  test 'adding to the other page reuses the product and hides the action when present in both' do
    get staff_menu_path
    assert_select 'button', text: 'Adicionar a Diárias / Brunch'
    assert_no_difference('MenuItem.count') do
      patch menu_membership_staff_menu_item_path(@product), params: { target: 'scheduled' }
    end
    assert_response :see_other
    assert @product.reload.scheduled_menu_visible?
    assert @product.normal_menu_visible?
    get staff_menu_path
    assert_select 'button', text: 'Adicionar a Diárias / Brunch', count: 0
    get staff_menu_path(menu_section: 'scheduled')
    assert_select '.menu-product-info strong', text: @product.name
    assert_select 'button', text: 'Adicionar à Carta', count: 0
  end

  test 'scheduled products are created in that page and can be added to the carta' do
    values = { name: 'Sopa de cenoura', category_id: @product.category_id, product_kind: 'soup', price: 2, available: '1', normal_menu_visible: '1' }
    post staff_menu_items_path, params: { menu_section: 'scheduled', menu_item: values }
    assert_response :see_other
    soup = @venue.menu_items.find_by!(name: 'Sopa de cenoura')
    assert soup.scheduled_menu_visible?
    assert_not soup.normal_menu_visible?
    get staff_menu_path
    assert_select '.menu-product-info strong', text: soup.name, count: 0
    get staff_menu_path(menu_section: 'scheduled')
    assert_select '.menu-product-info strong', text: soup.name
    patch menu_membership_staff_menu_item_path(soup), params: { target: 'carta', menu_section: 'scheduled' }
    assert soup.reload.normal_menu_visible?
    assert_redirected_to staff_menu_path(menu_section: 'scheduled', menu_status: 'active', open_category_id: soup.category_id)
  end

  test 'membership cannot modify another establishment' do
    _, _, foreign = build_venue
    patch menu_membership_staff_menu_item_path(foreign), params: { target: 'scheduled' }
    assert_response :not_found
    assert_not foreign.reload.scheduled_menu_visible?
  end
end
