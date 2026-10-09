require 'application_system_test_case'

class ProductClassificationSystemTest < ApplicationSystemTestCase
  test 'classifying a drink removes it from pending products and keeps preparation optional' do
    venue, table, product = build_venue
    product.update!(name: '7up')
    manager = venue_user(venue)
    page.current_window.resize_to(768, 1024)
    visit login_path
    fill_in 'Email', with: manager.email
    fill_in 'Palavra-passe', with: 'Test-password-123'
    click_button 'Entrar'
    assert_current_path staff_orders_path
    visit staff_menu_path
    assert_link 'Classificar produtos (1)'
    visit edit_staff_product_classification_path
    assert_no_selector 'select[name="classification[preparation_key]"]'
    assert_no_text 'Manter'
    select 'Bebida', from: 'Tipo de produto'
    check '7up'
    click_button 'Classificar selecionados'
    assert_text '1 produto(s) classificado(s).'
    assert_text 'Todos os produtos estão classificados.'
    assert_equal 'drink', product.reload.product_kind
    visit staff_menu_path
    assert_no_link 'Classificar produtos (1)'
    visit edit_staff_product_classification_path
    assert_no_selector '.classification-product', text: '7up'
    click_link 'Todos os produtos'
    assert_selector '.classification-product', text: '7up'
    assert_selector '.classification-product', text: 'Bebida'
    assert page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')
    visit edit_staff_menu_item_path(product)
    assert_no_selector 'select[name="menu_item[preparation_key]"]'
    venue.update!(production_areas_limit: 2, service_division_enabled: true)
    venue.ensure_default_production_areas!
    visit edit_staff_product_classification_path(scope: 'all')
    assert_selector 'select[name="classification[production_area_id]"]'
  end
end
