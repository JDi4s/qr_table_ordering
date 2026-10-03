require 'test_helper'

class Staff::MenuControllerTest < ActionDispatch::IntegrationTest
  test 'uncategorized is a separate tab and is not rendered as a category card' do
    venue, = build_venue
    manager = venue_user(venue)
    uncategorized = venue.categories.create!(name: 'Sem categoria', available: true)
    uncategorized.menu_items.create!(name: 'Produto solto', price: 2, available: true)
    sign_in(manager)

    get staff_menu_path(menu_status: 'uncategorized')

    assert_response :success
    assert_select '.staff-menu-status-tab', count: 4
    assert_select '.staff-menu-status-panel[data-menu-status="uncategorized"]', count: 1
    assert_select '.uncategorized-products', text: /Produto solto/
    assert_select "#category-#{uncategorized.id}", count: 0
  end

  test 'only the selected menu panel is rendered' do
    venue, = build_venue
    manager = venue_user(venue)
    sign_in(manager)

    get staff_menu_path(menu_status: 'active')

    assert_response :success
    assert_select '.staff-menu-status-panel', count: 1
    assert_select '.staff-menu-status-panel[data-menu-status="active"]', count: 1
  end

  test 'empty uncategorized storage is hidden and its direct URL returns to active categories' do
    venue, = build_venue
    manager = venue_user(venue)
    venue.categories.create!(name: 'Sem categoria', available: true)
    sign_in(manager)

    get staff_menu_path(menu_status: 'uncategorized')

    assert_response :success
    assert_select '.staff-menu-status-tab', count: 3
    assert_select '.staff-menu-status-tab', text: /Sem categoria/, count: 0
    assert_select '.staff-menu-status-panel[data-menu-status="active"]', count: 1
  end
  test 'category opens with compact products and keeps secondary actions available' do
    venue, _table, product = build_venue
    manager = venue_user(venue)
    sign_in(manager)

    get staff_menu_path(menu_status: 'active')

    assert_response :success
    assert_select '.menu-category-card details.staff-category-details[open]', count: 1
    assert_select '.menu-product-row', text: /#{Regexp.escape(product.name)}/
    assert_select '.menu-product-price', text: '10,00 €'
    assert_select '.menu-product-actions summary[aria-label]', count: 1
    assert_select "form[action='#{toggle_availability_staff_menu_item_path(product, menu_status: 'active')}']", count: 1
    assert_select "form[action='#{staff_menu_item_path(product, menu_status: 'active')}']", count: 1
  end

end
