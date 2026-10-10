require 'application_system_test_case'
class LunchMenuSystemTest < ApplicationSystemTestCase
  test 'customer composes complete menu and keeps selection over Turbo updates' do
    page.current_window.resize_to(390, 844)
    venue, table, product = build_venue
    menu = venue.create_lunch_menu!(active: true, weekdays: (0..6).to_a, starts_at: '00:00', ends_at: '23:59',
      individual_offers: [{ 'menu_item_id' => product.id, 'price' => '8.50' }], combo_enabled: true,
      combo_groups: LunchMenu::GROUPS.keys.to_h { |key| [key, [{ 'menu_item_id' => product.id, 'supplement' => key == 'drink' ? '1' : '0' }]] })
    TableVisit.activate_for!(table)
    visit new_table_order_path(table)
    assert_selector 'turbo-cable-stream-source[channel="MenuChannel"][connected]', visible: :all
    assert_selector '.menu-root-tab.is-active', text: 'Almoço'
    click_button 'Escolher menu'
    within('dialog[open]') do
      assert_text '13,00 €'
      page.save_screenshot(Rails.root.join('tmp/screenshots/lunch-choices-mobile.png'))
      click_button 'Adicionar menu'
    end
    within('#menu-root-lunch .customer-product-card') { find('.customer-add-button').click }
    assert_selector '.customer-cart-bar', text: '21,50 €'
    page.execute_script('window.scrollTo(0, 0)')
    page.save_screenshot(Rails.root.join('tmp/screenshots/lunch-customer.png'))
    product.update!(description: 'Prato fresco')
    assert_selector '.customer-product-card', text: 'Prato fresco', visible: :all
    assert_selector '.lunch-selected-row', text: 'Menu completo'
    assert_selector '.customer-cart-bar', text: '21,50 €'
    click_button 'Rever pedido'
    assert_text 'Confirme o seu pedido'
    assert_text 'Menu completo'
    assert_text 'Sem café'
    click_button 'Enviar pedido'
    assert_text 'Pedido enviado'
    assert_equal BigDecimal('21.50'), table.orders.last.total
    visit new_table_order_path(table)
    menu.update!(active: false)
    assert_no_selector '.menu-root-tab', text: 'Almoço'
    assert_selector '.customer-product-card', text: product.name
  end

  test 'manager configures a complete lunch menu without unit sales on mobile' do
    venue, _, product = build_venue
    product.update!(scheduled_menu_visible: true, product_kind: 'soup')
    manager = venue_user(venue)
    page.current_window.resize_to(390, 844)
    visit login_path
    fill_in 'Email', with: manager.email
    fill_in 'Palavra-passe', with: 'Test-password-123'
    click_on 'Entrar'
    assert_current_path staff_orders_path
    visit staff_menu_path
    click_link 'Diárias / Brunch'
    assert_selector '#managed-menu option[selected]', text: 'Menu de almoço'
    click_link 'Configurar'
    assert_text 'Menu de almoço'
    check 'Ativar menu de almoço'
    assert_no_text 'Vender à unidade'
    assert_no_selector '[data-sale-section="individual"]'
    choose 'exclude_plate', allow_label_click: true
    choose 'exclude_coffee', allow_label_click: true
    choose 'exclude_dessert', allow_label_click: true
    find('[data-group-panel="soup"] summary').click
    check "#{'combo_options[soup]'.parameterize}-#{product.id}"
    fill_in 'Preço do menu completo (€)', with: '8.50' 
    page.execute_script('window.scrollTo(0, 0)')
    page.save_screenshot(Rails.root.join('tmp/screenshots/lunch-management-mobile.png'))
    click_button 'Guardar menu de almoço'
    assert_text 'Menu de almoço guardado'
    assert_not venue.reload.lunch_menu.individual_enabled?
    assert venue.lunch_menu.combo_enabled?
    assert_equal BigDecimal('8.50'), venue.lunch_menu.combo_price
    assert_equal product.id, venue.lunch_menu.combo_groups['soup'].first['menu_item_id']
    assert_equal BigDecimal('10'), product.reload.price
  end
end

