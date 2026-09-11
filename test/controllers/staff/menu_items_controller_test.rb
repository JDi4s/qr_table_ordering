require 'test_helper'
class Staff::MenuItemsControllerTest < ActionDispatch::IntegrationTest
  test 'anonymous users must sign in' do
    get new_staff_menu_item_path
    assert_redirected_to login_path
  end

  test 'manager can archive and permanently delete an individual product without losing menu status' do
    venue, _, product = build_venue
    manager = venue_user(venue)
    sign_in(manager)

    delete staff_menu_item_path(product, menu_status: 'active')
    assert_redirected_to staff_menu_path(menu_status: 'active', open_category_id: product.category_id)
    assert product.reload.archived?

    assert_difference('MenuItem.count', -1) do
      delete purge_staff_menu_item_path(product, menu_status: 'archived')
    end
    assert_redirected_to staff_menu_path(menu_status: 'archived', open_category_id: product.category_id)
  end

  test 'completed order keeps its product name after the product is deleted' do
    venue, table, product = build_venue
    manager = venue_user(venue)
    order = build_order(table, product)
    original_name = order.order_items.first.display_name
    order.finalize_review!
    order.serve!
    sign_in(manager)

    delete purge_staff_menu_item_path(product, menu_status: 'archived')

    assert_response :see_other
    assert_nil order.order_items.first.reload.menu_item
    assert_equal original_name, order.order_items.first.display_name
  end

  test 'product in an ongoing order cannot be deleted' do
    venue, table, product = build_venue
    manager = venue_user(venue)
    build_order(table, product)
    sign_in(manager)

    assert_no_difference('MenuItem.count') do
      delete purge_staff_menu_item_path(product, menu_status: 'archived')
    end

    assert_redirected_to staff_menu_path(menu_status: 'archived', open_category_id: product.category_id)
    assert MenuItem.exists?(product.id)
  end
end
