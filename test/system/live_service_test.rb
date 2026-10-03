require 'application_system_test_case'
class LiveServiceTest < ApplicationSystemTestCase
  test 'staff receives new order and call live and customer receives the reviewed price' do
    venue, table, product = build_venue
    venue.update!(name: 'Café do Largo', plan: 'management')
    product.update!(name: 'Baguete de frango')
    manager = venue_user(venue)
    Capybara.using_session(:staff) do
      visit login_path
      fill_in 'Email', with: manager.email
      fill_in 'Palavra-passe', with: 'Test-password-123'
      click_on 'Entrar'
      assert_text 'Pedidos'
      assert_selector 'turbo-cable-stream-source[connected]', visible: :all
    end
    Capybara.using_session(:customer) do
      visit new_table_order_path(table)
      landing_screenshot('menu', width: 390, height: 780)
      2.times { find('.customer-product-card', text: product.name).click }
      click_on 'Rever pedido'
      assert_text '20,00 €'
      landing_screenshot('checkout', width: 390, height: 780)
      click_on 'Enviar pedido'
      assert_text 'Os meus pedidos'
      assert_selector 'turbo-cable-stream-source[connected]', visible: :all
    end
    order = table.orders.last
    Capybara.using_session(:staff) do
      assert_selector "#order_#{order.id}", text: product.name
      visit staff_orders_path
      page.execute_script("document.getElementById('order_#{order.id}').scrollIntoView({block: 'center'})")
      landing_screenshot('staff-orders', width: 1000, height: 730)
      click_on 'Avaliar pedido'
      find('summary', text: 'Alterar descrição ou preço', match: :first).click
      fill_in 'Mensagem ou alteração do artigo', with: 'Sem queijo'
      fill_in 'Novo preço por unidade (€)', with: '8.50'
      click_on 'Guardar decisão'
      assert_text 'Decisão guardada'
      click_on 'Concluir avaliação e aceitar pedido'
      assert_text 'Aceite'
    end
    Capybara.using_session(:customer) do
      assert_text 'Alteração:'
      assert_text '17,00 €'
      assert_text 'Aceite'
      page.save_screenshot(Rails.root.join('tmp/screenshots/customer.png'))
      landing_screenshot('customer-orders', width: 390, height: 780)
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

      4.times do |index|
        demo_order = build_order(table, product, customer: "landing-stats-#{index}")
        demo_order.order_items.each { |item| item.update!(status: 'accepted', paid_quantity: item.quantity) }
        demo_order.update!(status: 'served', served_at: Time.current, total: 30,
                           paid_at: Time.current, paid_by_user: manager)
        demo_order.payments.create!(user: manager, amount: 30, payment_method: 'card',
                                    paid_at: Time.current)
      end
      visit staff_reports_path(tab: 'statistics', analysis: 'revenue', metric: 'total',
                               view: 'day', date: Date.current.iso8601)
      assert_text '120,00 €'
      page.execute_script("document.querySelector('.report-stat-grid').scrollIntoView({block: 'start'})")
      landing_screenshot('statistics', width: 1180, height: 760)
    end
  end

  private

  def landing_screenshot(name, width:, height:)
    browser = page.driver.browser
    browser.execute_cdp('Emulation.setDeviceMetricsOverride',
      width: width, height: height, deviceScaleFactor: 2, mobile: false)
    page.save_screenshot(Rails.root.join("tmp/screenshots/landing-#{name}.png"))
  ensure
    browser&.execute_cdp('Emulation.clearDeviceMetricsOverride')
  end
end
