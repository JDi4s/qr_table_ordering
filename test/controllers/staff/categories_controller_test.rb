require 'test_helper'
class Staff::CategoriesControllerTest < ActionDispatch::IntegrationTest
  test 'anonymous users must sign in' do
    get new_staff_category_path
    assert_redirected_to login_path
  end

  test 'manager deletes a category and moves its products to uncategorized' do
    venue, = build_venue
    manager = venue_user(venue)
    category = venue.categories.find_by!(name: 'Comida')
    product = category.menu_items.first
    sign_in(manager)

    assert_no_difference('Category.count') do
      delete purge_staff_category_path(category, menu_status: 'archived')
    end

    assert_redirected_to staff_menu_path(menu_status: 'archived')
    assert_not Category.exists?(category.id)
    assert_equal 'Sem categoria', product.reload.category.name
  end

  test 'manager can delete a category used by an ongoing order because the product is preserved' do
    venue, table, product = build_venue
    manager = venue_user(venue)
    category = product.category
    build_order(table, product)
    sign_in(manager)

    assert_no_difference('Category.count') do
      delete purge_staff_category_path(category, menu_status: 'archived')
    end

    assert_redirected_to staff_menu_path(menu_status: 'archived')
    assert_not Category.exists?(category.id)
    assert_equal 'Sem categoria', product.reload.category.name
    assert Order.exists?(table.orders.first.id)
  end

  test 'deleting a parent category keeps and reparents its subcategories' do
    venue, = build_venue
    manager = venue_user(venue)
    parent = venue.categories.create!(name: 'Parent', available: true)
    child = venue.categories.create!(name: 'Child', parent: parent, available: true)
    sign_in(manager)

    assert_difference('Category.count', -1) do
      delete purge_staff_category_path(parent, menu_status: 'active')
    end

    assert_redirected_to staff_menu_path(menu_status: 'active')
    assert_nil child.reload.parent_id
  end
end
