require 'application_system_test_case'
class LiveServiceTest < ApplicationSystemTestCase
  test 'staff receives new order and call live and customer receives the reviewed price' do
    venue, table, product = build_venue
    manager = venue_user(venue)
    Capybara.using_session(:staff) do
      visit login_path
      fill_in 'Email', with: manager.email
      fill_in 'Palavra-passe', with: 'Test-password-123'
      click_on 'Entrar'
      assert_text 'Pedidos e chamadas'
      assert_selector 'turbo-cable-stream-source[connected]', visible: :all
    end
    Capybara.using_session(:customer) do
      visit new_table_order_path(table)
      fill_in "quantity_#{product.id}", with: 2
      click_on 'Rever pedido'
      assert_text '20,00 €'
      click_on 'Enviar pedido'
      assert_text 'Os meus pedidos'
      assert_selector 'turbo-cable-stream-source[connected]', visible: :all
    end
    order = table.orders.last
    Capybara.using_session(:staff) do
      assert_selector "#order_#{order.id}", text: product.name
      click_on 'Abrir pedido'
      fill_in 'Alteração a confirmar pelo cliente (opcional)', with: 'Sem queijo'
      fill_in 'Preço por unidade (€)', with: '8.50'
      click_on 'Guardar decisão'
      assert_text 'Decisão guardada'
      click_on 'Concluir avaliação e avisar cliente'
      assert_text 'Aguarda confirmação do cliente'
    end
    Capybara.using_session(:customer) do
      assert_text 'O seu pedido tem alterações.'
      assert_text '17,00 €'
      click_on 'Aceitar este pedido atualizado'
      assert_text 'Alterações aceites.'
      assert_text 'Aceite'
      page.save_screenshot(Rails.root.join('tmp/screenshots/customer.png'))
      visit new_table_order_path(table)
      click_on 'Chamar funcionário'
      assert_text 'O funcionário foi chamado'
    end
    Capybara.using_session(:staff) do
      visit staff_orders_path
      assert_text 'Mesa 1 — assistência'
      click_on 'Assumir chamada'
      assert_text 'Assumida por'
      page.save_screenshot(Rails.root.join('tmp/screenshots/staff.png'))
      click_on 'Marcar como atendida'
      assert_no_text 'Mesa 1 — assistência'
    end
  end
end
