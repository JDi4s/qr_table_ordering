require 'application_system_test_case'
class MenuClaritySystemTest < ApplicationSystemTestCase
  test 'manager saves a typed combo in one step and layout fits mobile tablet and desktop' do
    venue, _, soup = build_venue
    soup.update!(scheduled_menu_visible: true, name: 'Sopa de legumes', product_kind: 'soup')
    manager = venue_user(venue)
    visit login_path
    fill_in 'Email', with: manager.email
    fill_in 'Palavra-passe', with: 'Test-password-123'
    click_button 'Entrar'
    assert_current_path staff_orders_path
    visit edit_staff_lunch_menu_path
    check 'Ativar menu de almoço'
    assert_no_text 'Vender à unidade'
    choose 'exclude_plate', allow_label_click: true
    choose 'exclude_coffee', allow_label_click: true
    choose 'exclude_dessert', allow_label_click: true
    find('[data-group-panel=soup] summary').click
    check "#{'combo_options[soup]'.parameterize}-#{soup.id}"
    assert_text '1 produto selecionado'
    click_button 'Guardar menu de almoço'
    assert_text 'Menu de almoço guardado'
    assert_equal ['soup'], venue.reload.lunch_menu.groups.map { |g| g['key'] }
    assert venue.lunch_menu.groups_configured?
    assert_checked_field 'exclude_coffee', visible: :all
    [[390,844],[768,1024],[1024,768],[1440,900]].each do |width,height|
      page.current_window.resize_to(width,height)
      [edit_staff_lunch_menu_path, staff_menu_path].each_with_index do |path,index|
        visit path
        assert page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth'), "Overflow at #{width} on #{path}"
        page.save_screenshot(Rails.root.join("tmp/screenshots/menu-clarity-#{width}-#{index}.png"))
      end
    end
  end
  test 'manager creates a named group and selects matching products' do
    venue, _, soup = build_venue
    soup.update!(scheduled_menu_visible: true, name: 'Sopa de cenoura', product_kind: 'soup')
    manager = venue_user(venue)
    visit login_path
    fill_in 'Email', with: manager.email
    fill_in 'Palavra-passe', with: 'Test-password-123'
    click_button 'Entrar'
    assert_current_path staff_orders_path
    visit edit_staff_lunch_menu_path
    %w[soup plate coffee dessert].each { |key| choose "exclude_#{key}", allow_label_click: true }
    assert_no_text 'Vender à unidade'
    click_button '+ Criar grupo'
    within '[data-group-editor=extra_0]' do
      fill_in 'Nome do grupo', with: 'Sopas da casa'
      select 'Sopa', from: 'Tipo de produtos'
    end
    find('[data-group-panel=extra_0] summary').click
    check "#{'combo_options[extra_0]'.parameterize}-#{soup.id}"
    check 'Ativar menu de almoço'
    click_button 'Guardar menu de almoço'
    assert_text 'Menu de almoço guardado'
    menu = venue.reload.lunch_menu
    assert_equal ['Sopas da casa'], menu.groups.map { |g| g['name'] }
    assert_equal ['soup'], menu.groups.first['types']
    assert_equal soup.id, menu.combo_groups['extra_0'].first['menu_item_id']
    assert_field 'Nome do grupo', with: 'Sopas da casa'
  end
end

