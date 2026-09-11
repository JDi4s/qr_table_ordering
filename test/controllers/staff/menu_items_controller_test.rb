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

  test 'manager deletes all uncategorized products and stays on that menu tab' do
    venue, = build_venue
    manager = venue_user(venue)
    category = venue.categories.create!(name: 'Sem categoria', available: true)
    category.menu_items.create!(name: 'Sem grupo 1', price: 2, available: true)
    category.menu_items.create!(name: 'Sem grupo 2', price: 3, available: false)
    sign_in(manager)

    assert_difference('MenuItem.count', -2) do
      delete purge_uncategorized_staff_menu_items_path(menu_status: 'uncategorized')
    end

    assert_redirected_to staff_menu_path(menu_status: 'uncategorized')
    assert_empty category.menu_items.reload
  end

  test 'bulk delete keeps uncategorized products used by ongoing orders' do
    venue, table, = build_venue
    manager = venue_user(venue)
    category = venue.categories.create!(name: 'Sem categoria', available: true)
    blocked = category.menu_items.create!(name: 'Em curso', price: 2, available: true)
    removable = category.menu_items.create!(name: 'Livre', price: 3, available: true)
    build_order(table, blocked)
    sign_in(manager)

    assert_difference('MenuItem.count', -1) do
      delete purge_uncategorized_staff_menu_items_path(menu_status: 'uncategorized')
    end

    assert MenuItem.exists?(blocked.id)
    assert_not MenuItem.exists?(removable.id)
    assert_redirected_to staff_menu_path(menu_status: 'uncategorized')
  end

  test 'manager deletes the archived category tree and archived products in one action' do
    venue, = build_venue
    manager = venue_user(venue)
    parent = venue.categories.create!(name: 'Arquivo', available: false, archived_at: Time.current)
    child = venue.categories.create!(name: 'Filha', parent: parent, available: true)
    product = child.menu_items.create!(name: 'Produto antigo', price: 4, available: true)
    sign_in(manager)

    assert_difference('Category.count', -2) do
      assert_difference('MenuItem.count', -1) do
        delete purge_archived_staff_menu_items_path(menu_status: 'archived')
      end
    end

    assert_not Category.exists?(parent.id)
    assert_not Category.exists?(child.id)
    assert_not MenuItem.exists?(product.id)
    assert_redirected_to staff_menu_path(menu_status: 'archived')
  end
end
