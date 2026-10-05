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

  test 'unavailable products stay reachable inside active categories and subcategories' do
    venue, _, product = build_venue
    product.update!(available: false)
    parent = product.category
    child = venue.categories.create!(name: 'Filha ativa', parent: parent)
    nested = child.menu_items.create!(name: 'Produto indisponível na filha', price: 3, available: false)
    child.menu_items.create!(name: 'Disponível', price: 2, available: true)
    sign_in(venue_user(venue))

    get staff_menu_path(menu_status: 'unavailable', open_category_id: child.id)

    assert_response :success
    assert_select '.menu-product-row', text: /#{Regexp.escape(product.name)}/
    assert_select '.menu-product-row', text: /#{Regexp.escape(nested.name)}/
    assert_select '.menu-product-row', count: 2
    assert_select ".staff-menu-status-tab[href='#{staff_menu_path(menu_status: 'unavailable')}'] span", text: '2'
    assert_select "#category-#{child.id} > details[open]"
  end

  test 'unavailable parent exposes its non archived descendants but archived records stay in archives' do
    venue, _, product = build_venue
    product.category.update!(available: false)
    child = venue.categories.create!(name: 'Filha', parent: product.category, available: true)
    child.menu_items.create!(name: 'Produto da filha', price: 3)
    child.menu_items.create!(name: 'Arquivo', price: 3, archived_at: Time.current)
    sign_in(venue_user(venue))

    get staff_menu_path(menu_status: 'unavailable')
    assert_select '.menu-product-row', text: /Produto da filha/
    assert_select '.menu-product-row', text: /Arquivo/, count: 0
    get staff_menu_path(menu_status: 'active')
    assert_select '.menu-product-row', count: 0
    get staff_menu_path(menu_status: 'archived')
    assert_select '.menu-product-row', text: /Arquivo/
  end

end
