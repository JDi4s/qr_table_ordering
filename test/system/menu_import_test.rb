require 'application_system_test_case'

class MenuImportSystemTest < ApplicationSystemTestCase
  test 'mobile selection cascades categories shows partial selection and imports the reviewed products' do
    source, _, product = build_venue
    source.update!(name: 'Bistrô Farol')
    product.update!(name: 'Baguete')
    child = source.categories.create!(name: 'Pastelaria', parent: product.category)
    cake = child.menu_items.create!(name: 'Pastel de nata', price: 1.50)
    product.category.menu_items.create!(name: 'Pão de milho', price: 1)
    destination = Establishment.create!(name: 'Café Novo', slug: "novo-#{SecureRandom.hex(4)}")
    admin = User.create!(email: "admin-#{SecureRandom.hex(4)}@example.com", password: 'Test-password-123', role: 'platform_admin')
    page.current_window.resize_to(390, 844)
    visit login_path
    fill_in 'Email', with: admin.email
    fill_in 'Palavra-passe', with: 'Test-password-123'
    click_on 'Entrar'
    assert_current_path admin_establishments_path
    visit new_admin_establishment_menu_import_path(destination)
    select 'Bistrô Farol', from: 'De que estabelecimento?'
    click_on 'Ver menu'
    assert_text '3 produtos selecionados'
    uncheck "import_category_#{child.id}"
    assert_no_checked_field "import_product_#{cake.id}"
    assert_text '2 produtos selecionados'
    assert page.evaluate_script("document.getElementById('import_category_#{product.category_id}').indeterminate")
    click_button 'Desmarcar tudo'
    assert_button 'Rever importação →', disabled: true
    check "import_product_#{product.id}"
    assert_text '1 produto selecionado'
    page.execute_script('window.scrollTo(0, 0)')
    page.save_screenshot(Rails.root.join('tmp/screenshots/menu-import-mobile.png'))
    click_button 'Rever importação →'
    assert_text 'Rever importação'
    click_button 'Alterar seleção'
    assert_checked_field "import_product_#{product.id}"
    assert_no_checked_field "import_product_#{cake.id}"
    click_button 'Rever importação →'
    page.save_screenshot(Rails.root.join('tmp/screenshots/menu-import-review-mobile.png'))
    click_button 'Confirmar e importar menu'
    assert_text 'Menu importado para Café Novo'
    assert_equal ['Baguete'], destination.menu_items.pluck(:name)
  end
end
