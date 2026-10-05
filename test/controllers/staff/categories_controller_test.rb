require 'test_helper'

class Staff::CategoriesControllerTest < ActionDispatch::IntegrationTest
  test 'anonymous users must sign in' do
    get new_staff_category_path
    assert_redirected_to login_path
  end

  test 'deleting a category with products is blocked without moving them' do
    venue, = build_venue
    category = venue.categories.find_by!(name: 'Comida')
    product = category.menu_items.first
    sign_in(venue_user(venue))

    assert_no_difference(['Category.count', 'MenuItem.count']) do
      delete purge_staff_category_path(category, menu_status: 'archived')
    end

    assert_redirected_to staff_menu_path(menu_status: 'archived', open_category_id: category.id)
    assert_equal category.id, product.reload.category_id
    assert_includes flash[:alert], 'Mova ou elimine primeiro'
    assert_not venue.categories.exists?(name: 'Sem categoria')
  end

  test 'deleting a category with subcategories is blocked without reparenting them' do
    venue, = build_venue
    parent = venue.categories.create!(name: 'Parent', available: true)
    child = venue.categories.create!(name: 'Child', parent: parent, available: true)
    sign_in(venue_user(venue))

    assert_no_difference('Category.count') { delete purge_staff_category_path(parent, menu_status: 'active') }

    assert_redirected_to staff_menu_path(menu_status: 'active', open_category_id: parent.id)
    assert_equal parent.id, child.reload.parent_id
  end

  test 'an empty category can be deleted' do
    venue, = build_venue
    category = venue.categories.create!(name: 'Vazia')
    sign_in(venue_user(venue))

    assert_difference('Category.count', -1) { delete purge_staff_category_path(category, menu_status: 'archived') }

    assert_redirected_to staff_menu_path(menu_status: 'archived')
  end

  test 'editing a category preserves the originating menu tab and category' do
    venue, = build_venue
    category = venue.categories.create!(name: 'Desativada', available: false)
    sign_in(venue_user(venue))

    get edit_staff_category_path(category, menu_status: 'unavailable', open_category_id: category.id)
    assert_select 'input[name="menu_status"][value="unavailable"]'
    patch staff_category_path(category), params: {
      menu_status: 'unavailable', open_category_id: category.id,
      category: { name: 'Novo nome', available: false }
    }

    assert_redirected_to staff_menu_path(menu_status: 'unavailable', open_category_id: category.id)
    assert_equal 'Novo nome', category.reload.name
  end
end
