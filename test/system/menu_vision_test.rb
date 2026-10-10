require 'application_system_test_case'
class MenuVisionSystemTest < ApplicationSystemTestCase
  test 'manager selects a menu and uses product actions across screen sizes' do
    venue, _, product = build_venue
    product.update!(product_kind: 'soup', scheduled_menu_visible: true, normal_menu_visible: false, name: 'Sopa de cenoura')
    ScheduledMenuProducts.add!(venue, product, kind: 'lunch', group_key: 'soup', price: 2)
    user = venue_user(venue)
    visit login_path
    fill_in 'Email', with: user.email
    fill_in 'Palavra-passe', with: 'Test-password-123'
    click_button 'Entrar'
    assert_current_path staff_orders_path
    [[390,844],[768,1024],[1024,768],[1440,900]].each do |width,height|
      page.current_window.resize_to(width,height)
      visit staff_menu_path(menu_section: 'scheduled')
      assert_selector '.menu-group-grid .menu-product-info', text: 'Sopa de cenoura'
      assert page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')
      page.save_screenshot(Rails.root.join("tmp/screenshots/menu-vision-#{width}.png"))
    end
    select 'Pequeno-almoço / Brunch', from: 'Menu que estás a gerir'
    assert_no_selector '.menu-group-grid .menu-product-info', text: 'Sopa de cenoura'
    select 'Menu de almoço', from: 'Menu que estás a gerir'
    within '.menu-group-grid .menu-product-row' do
      find('summary').click
      click_button 'Adicionar à Carta'
    end
    assert_text 'Produto adicionado'
    assert product.reload.normal_menu_visible?
    within '.menu-group-grid .menu-product-row' do
      find('summary').click
      assert_no_button 'Adicionar à Carta'
    end
    click_link 'Carta', match: :first
    assert_selector '.menu-product-info', text: 'Sopa de cenoura'
  end
end
