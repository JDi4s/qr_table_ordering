require 'application_system_test_case'

class ProductInformationSystemTest < ApplicationSystemTestCase
  test 'customer opens product information without adding quantities and closes with X or Escape' do
    venue, table, item = build_venue
    item.update!(description: 'Croissant com queijo e fiambre.', allergens: %w[gluten milk eggs],
                 nutrition_enabled: true, nutrition_energy: 312, nutrition_protein: 10,
                 nutrition_carbs: 28, nutrition_fat: 17)
    [390, 1440].each do |width|
      page.current_window.resize_to(width, 900)
      visit new_table_order_path(table)
      assert_text 'A tua mesa ainda não está ativa'
      opener = find('.customer-product-info-button')
      opener.click
      assert_selector 'dialog[open]', text: 'Informação nutricional'
      within('dialog[open]') do
        assert_text 'Croissant com queijo e fiambre.'
        assert_text 'Glúten'
        assert_text 'Leite'
        assert_text '312 kcal'
        assert_no_text 'Sal'
        assert_selector 'button', count: 1
        assert_no_button 'Voltar ao menu'
      end
      assert_equal '0', find('.customer-quantity-input', visible: :all).value
      assert page.evaluate_script("(() => { const r = document.querySelector('dialog[open]').getBoundingClientRect(); return r.left >= 0 && r.right <= innerWidth && r.top >= 0 && r.bottom <= innerHeight; })()")
      page.save_screenshot(Rails.root.join("tmp/screenshots/product-information-#{width}.png"))
      find('.product-info-close').click
      assert_no_selector 'dialog[open]'
      assert_equal opener[:'aria-label'], page.evaluate_script('document.activeElement.getAttribute("aria-label")')
      opener.click
      page.send_keys :escape
      assert_no_selector 'dialog[open]'
      assert_equal '0', find('.customer-quantity-input', visible: :all).value
    end
    venue.update!(accepting_orders: false)
    visit new_table_order_path(table)
    find('.customer-product-info-button').click
    assert_selector 'dialog[open]', text: 'Informação nutricional'
  end

  test 'manager chooses optional information and previews it before creating a product' do
    venue, table, item = build_venue
    manager = venue_user(venue)
    page.current_window.resize_to(390, 900)
    visit login_path
    assert_selector 'form[action="/login"]'
    fill_in 'Email', with: manager.email
    fill_in 'Palavra-passe', with: 'Test-password-123'
    click_on 'Entrar'
    assert_current_path staff_orders_path
    visit new_staff_menu_item_path
    fill_in 'Nome', with: 'Croissant com detalhes'
    assert_no_selector '#menu_item_description'
    find('summary', text: 'Imagem e descrição').click
    fill_in 'Descrição (opcional)', with: 'Queijo e fiambre.'
    select item.category.name, from: 'Categoria'
    fill_in 'Preço (€)', with: '3.50'
    select 'Snack / sandes', from: 'Tipo de produto'
    assert_no_selector '#menu_item_nutrition_energy'
    find('summary', text: 'Alergénios').click
    check 'Leite'
    check 'Glúten'
    find('summary', text: 'Informação nutricional').click
    check 'Adicionar informação nutricional'
    select 'Por porção', from: 'Valores apresentados'
    fill_in 'Tamanho da porção', with: '1 croissant · 120 g'
    fill_in 'Tamanho da porção', with: ''
    find('summary', text: 'Informação nutricional').click
    click_on 'Guardar produto'
    assert_selector 'details.product-nutrition-fields[open]'
    fill_in 'Tamanho da porção', with: '1 croissant · 120 g'
    fill_in 'Energia (kcal)', with: '312'
    fill_in 'Proteínas (g)', with: '10'
    click_on 'Pré-visualizar cartão'
    find('[aria-label="Pré-visualizar informação do produto"]').click
    within('.product-preview-information') do
      assert_text 'Contém: Glúten, Leite'
      assert_text 'Por porção · 1 croissant · 120 g'
      assert_text '312 kcal'
    end
    find('[aria-label="Fechar pré-visualização"]').click
    uncheck 'Adicionar informação nutricional'
    assert_no_selector '#menu_item_nutrition_energy'
    check 'Adicionar informação nutricional'
    assert_field 'Energia (kcal)', with: '312'
    click_on 'Guardar produto'
    assert_text 'Produto criado.'
    created = venue.menu_items.find_by!(name: 'Croissant com detalhes')
    assert_equal %w[gluten milk], created.allergens
    assert_equal 312, created.nutrition_energy
    visit edit_staff_menu_item_path(created)
    find('summary', text: 'Alergénios').click
    assert_checked_field 'Leite'
    find('summary', text: 'Informação nutricional').click
    assert_field 'Tamanho da porção', with: '1 croissant · 120 g'
    assert page.evaluate_script('document.documentElement.scrollWidth <= innerWidth')
    page.execute_script('arguments[0].scrollIntoView({block: "center"})', find('.product-nutrition-fields'))
    page.save_screenshot(Rails.root.join('tmp/screenshots/product-information-form-mobile.png'))
  end
end
