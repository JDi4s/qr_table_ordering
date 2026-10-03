require 'application_system_test_case'

class StaffOrdersBoardTest < ApplicationSystemTestCase
  test 'mobile board keeps counts, filters, actions and navigation usable' do
    venue, table, product = build_venue
    manager = venue_user(venue)
    order = build_order(table, product)

    page.current_window.resize_to(390, 844)
    visit login_path
    fill_in 'Email', with: manager.email
    fill_in 'Palavra-passe', with: 'Test-password-123'
    click_on 'Entrar'

    assert_selector '.staff-summary-card [data-staff-board-target="pendingCount"]', text: '1'
    assert_selector "#order_#{order.id}", text: 'Mesa 1'
    assert_selector "#order_#{order.id}", text: 'Avaliar pedido'
    assert_selector '.staff-nav-toggle[aria-expanded="false"]'
    assert_selector '.staff-nav-toggle svg path', visible: :all
    assert_selector '.staff-main-nav a.is-active', text: 'Pedidos', visible: :all
    assert_no_selector '.staff-main-nav a.is-active', text: 'Histórico', visible: :all
    assert_no_selector '.staff-main-nav a', visible: true

    find('.staff-nav-toggle').click
    assert_selector '.staff-nav-toggle[aria-expanded="true"]'
    assert_selector '.staff-main-nav a', text: 'Mesas', visible: true
    find('.staff-nav-toggle').click
    assert_selector '.staff-nav-toggle[aria-expanded="false"]'

    find('.staff-board-tab', text: 'Em curso').click
    assert_no_selector "#order_#{order.id}", visible: true
    find('.staff-board-tab', text: 'Novos').click
    assert_selector "#order_#{order.id}", text: product.name
    page.save_screenshot(Rails.root.join('tmp/screenshots/staff-orders-mobile.png'))

    visit history_staff_orders_path
    assert_selector '.staff-main-nav a.is-active', text: 'Histórico', visible: :all
    assert_no_selector '.staff-main-nav a.is-active', text: 'Pedidos', visible: :all
  end
end
