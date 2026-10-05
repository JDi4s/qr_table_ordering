require 'application_system_test_case'

class StaffMenuTest < ApplicationSystemTestCase
  test 'editing an unavailable product preserves the tab expanded category and mobile scroll' do
    venue, _, product = build_venue
    category = product.category
    30.times { |number| category.menu_items.create!(name: format('Indisponível %02d', number), price: 2, available: false) }
    manager = venue_user(venue)
    page.current_window.resize_to(390, 844)
    visit login_path
    fill_in 'Email', with: manager.email
    fill_in 'Palavra-passe', with: 'Test-password-123'
    click_on 'Entrar'
    assert_current_path staff_orders_path, wait: 10
    assert_no_button 'Entrar'
    visit staff_menu_path(menu_status: 'unavailable')

    assert_selector "#category-#{category.id} > details[open]"
    row = find('.menu-product-row', text: 'Indisponível 29')
    page.execute_script('arguments[0].scrollIntoView({block: "center"})', row)
    original_scroll = page.evaluate_script('window.scrollY')
    assert_operator original_scroll, :>, 500
    within(row) { click_on 'Editar' }

    assert_selector 'h1', text: 'Editar produto'
    fill_in 'Nome', with: 'Indisponível 29 revisto'
    click_on 'Guardar alterações'

    assert_selector '.staff-menu-status-panel[data-menu-status="unavailable"]'
    assert_selector "#category-#{category.id} > details[open]"
    assert_selector '.menu-product-row', text: 'Indisponível 29 revisto'
    assert_no_selector '.staff-menu-status-panel[data-menu-status="active"]'
    Timeout.timeout(Capybara.default_max_wait_time) do
      sleep 0.05 until (page.evaluate_script('window.scrollY') - original_scroll).abs < 100
    end
    page.save_screenshot(Rails.root.join('tmp/screenshots/staff-menu-context-mobile.png'))
  end
end
