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
      delete purge_staff_category_path(category)
    end

    assert_redirected_to staff_menu_path
    assert_not Category.exists?(category.id)
    assert_equal 'Sem categoria', product.reload.category.name
  end

  test 'manager cannot delete a category used by an ongoing order' do
    venue, table, product = build_venue
    manager = venue_user(venue)
    category = product.category
    build_order(table, product)
    sign_in(manager)

    assert_no_difference('Category.count') do
      delete purge_staff_category_path(category)
    end

    assert_redirected_to staff_menu_path
    assert Category.exists?(category.id)
    assert_equal category, product.reload.category
  end
end
