require 'application_system_test_case'
class MenuClaritySystemTest < ApplicationSystemTestCase
  test 'manager saves a typed combo in one step and layout fits mobile tablet and desktop' do
    venue, _, soup = build_venue
    soup.update!(name: 'Sopa de legumes', product_kind: 'soup')
    manager = venue_user(venue)
    visit login_path
    fill_in 'Email', with: manager.email
    fill_in 'Palavra-passe', with: 'Test-password-123'
    click_button 'Entrar'
    assert_current_path staff_orders_path
    visit edit_staff_lunch_menu_path
    check 'Ativar menu de almoço'
    uncheck 'Vender à unidade'
    check 'Vender menu completo'
    uncheck 'Prato'
    uncheck 'Bebida'
    check "#{'combo_options[soup]'.parameterize}-#{soup.id}"
    assert_text '1 produto selecionado'
    click_button 'Guardar menu de almoço'
    assert_text 'Menu de almoço guardado'
    assert_equal ['soup'], venue.reload.lunch_menu.groups.map { |g| g['key'] }
    [[390,844],[768,1024],[1024,768],[1440,900]].each do |width,height|
      page.current_window.resize_to(width,height)
      [edit_staff_lunch_menu_path, staff_menu_path].each_with_index do |path,index|
        visit path
        assert page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth'), "Overflow at #{width} on #{path}"
        page.save_screenshot(Rails.root.join("tmp/screenshots/menu-clarity-#{width}-#{index}.png"))
      end
    end
  end
end
