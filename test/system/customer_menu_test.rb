require 'application_system_test_case'

class CustomerMenuTest < ApplicationSystemTestCase
  test 'quantity controls update the total and survive returning from checkout on mobile' do
    _venue, table, product = build_venue
    product.update!(name: 'Café', price: 0.85)
    page.driver.browser.manage.window.resize_to(390, 780)
    visit new_table_order_path(table)

    within('.customer-product-card', text: 'Café') do
      assert_selector '.quantity-value', text: '0'
      assert_selector '.customer-remove-button:disabled'
      find('.customer-add-button').click
      find('.customer-add-button').click
      assert_selector '.quantity-value', text: '2'
      find('.customer-remove-button').click
      assert_selector '.quantity-value', text: '1'
    end
    assert_selector '[data-customer-menu-target="cartTotal"]', text: '0,85 €'
    click_on 'Rever pedido'
    assert_text '0,85 €'
    click_on 'Voltar ao menu'
    within('.customer-product-card', text: 'Café') do
      assert_selector '.quantity-value', text: '1'
      find('.customer-remove-button').click
      assert_selector '.quantity-value', text: '0'
      assert_selector '.customer-remove-button:disabled'
    end
    assert_no_selector '.customer-cart-bar'

    page.execute_script("const input = document.querySelector('.customer-quantity-input'); input.value = '98'; document.querySelector('.customer-add-button').click()")
    within('.customer-product-card', text: 'Café') do
      assert_selector '.quantity-value', text: '99'
      assert_selector '.customer-add-button:disabled'
      find('.customer-remove-button').click
      assert_selector '.quantity-value', text: '98'
      assert_selector '.customer-add-button:not(:disabled)'
    end
  end
end
