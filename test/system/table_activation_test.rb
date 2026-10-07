require 'application_system_test_case'

class TableActivationSystemTest < ApplicationSystemTestCase
  test 'pending QR signals once, staff activates in compact panel and customer unlocks without refresh' do
    venue, table, product = build_venue
    venue.update!(name: 'Café de teste de mesas')
    staff = venue_user(venue)
    Capybara.using_session(:activation_staff) do
      page.current_window.resize_to(390, 844)
      visit login_path
      assert_current_path login_path
      assert_selector 'form[action="/login"]'
      fill_in 'Email', with: staff.email
      fill_in 'Palavra-passe', with: 'Test-password-123'
      click_on 'Entrar'
      assert_text venue.name
      assert_selector 'body[data-table-activation-connected="true"]', visible: :all
      assert_button 'Ativar mesa'
      assert_no_selector '.table-activation-panel'
      click_on 'Ativar mesa'
      click_on 'Testar som'
      assert_text 'Som ativo e testado neste dispositivo.'
      find('.table-activation-close').click
      # Capture actual realtime sound requests without relying on physical
      # speakers or Chrome autoplay settings in headless CI.
      page.execute_script(<<~JS)
        window.activationBeeps = [];
        const controller = window.Stimulus.getControllerForElementAndIdentifier(document.body, 'staff-orders');
        const original = controller.beep.bind(controller);
        controller.beep = async (kind) => { window.activationBeeps.push(kind); return original(kind); };
      JS
    end
    Capybara.using_session(:activation_duplicate_scan) do
      visit new_table_order_path(table)
      assert_text 'A tua mesa ainda não está ativa'
    end
    Capybara.using_session(:activation_customer) do
      page.current_window.resize_to(390, 844)
      visit new_table_order_path(table)
      assert_text 'A tua mesa ainda não está ativa'
      find('.customer-add-button').click
      click_on 'Rever pedido'
      assert_button 'Enviar pedido', disabled: true
    end
    Capybara.using_session(:activation_staff) do
      assert_selector '.table-activation-trigger .table-activation-dot'
      assert_equal ['activation'], page.evaluate_script('window.activationBeeps')
      click_on 'Ativar mesa'
      assert_selector '.table-activation-panel'
      page.save_screenshot(Rails.root.join('tmp/screenshots/table-activation-waiting-mobile.png'))
      within('.table-activation-row[data-table-number="1"]') do
        assert_text 'QR lido'
        click_on 'Ativar'
      end
      assert_text 'Mesa 1 ativada'
      assert_no_selector '.table-activation-panel'
      assert_equal 'running', page.evaluate_script('window.bocatoStaffAudioContext?.state'), 'Activating a table must not close the unlocked sound context'
      click_on 'Ativar mesa'
      assert_selector '.table-activation-row .table-activation-active', text: 'Ativa'
      assert page.evaluate_script('document.documentElement.scrollWidth <= innerWidth')
      page.save_screenshot(Rails.root.join('tmp/screenshots/table-activation-mobile.png'))
      find('.table-activation-close').click
    end
    Capybara.using_session(:activation_customer) do
      assert_button 'Enviar pedido', disabled: false
      assert_no_text 'A tua mesa ainda não está ativa'
      assert_selector '.customer-table-activated', text: 'Mesa ativa'
      assert_text 'A equipa ativou a tua mesa. Já podes enviar o pedido.'
      assert page.evaluate_script("(() => { const r = document.querySelector('.customer-table-activated').getBoundingClientRect(); return r.left >= 0 && r.right <= innerWidth; })()")
      click_on 'Fechar aviso de mesa ativa'
      assert_no_selector '.customer-table-activated'
      assert_button 'Enviar pedido', disabled: false
      click_on 'Enviar pedido'
      assert_text 'Os meus pedidos'
    end
    Capybara.using_session(:activation_customer_again) do
      visit new_table_order_path(table)
      assert_no_text 'A tua mesa ainda não está ativa'
      assert_no_selector '.customer-table-activated'
    end
    Capybara.using_session(:activation_staff) do
      assert_equal ['activation'], page.evaluate_script('window.activationBeeps') if page.evaluate_script('Boolean(window.activationBeeps)')
      page.current_window.resize_to(1440, 900)
      click_on 'Ativar mesa'
      assert_selector '.table-activation-panel'
      assert page.evaluate_script("(() => { const r = document.querySelector('.table-activation-panel').getBoundingClientRect(); return r.left >= 0 && r.right <= innerWidth; })()")
      page.save_screenshot(Rails.root.join('tmp/screenshots/table-activation-desktop.png'))
      find('.table-activation-close').click
    end
    order = table.orders.last
    order.finalize_review!
    order.serve!
    order.mark_paid!(staff)
    Capybara.using_session(:activation_customer) do
      assert_selector '.customer-previous-visits', text: 'Pedidos anteriores (1)'
      assert_text 'Ainda não tens pedidos nesta visita'
    end
    Capybara.using_session(:activation_customer_again) do
      assert_text 'Esta visita terminou'
      find('.customer-add-button').click
      click_on 'Rever pedido'
      assert_text 'A tua mesa ainda não está ativa'
    end
  end
end
