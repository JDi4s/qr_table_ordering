require 'application_system_test_case'

class NotificationPositionTest < ApplicationSystemTestCase
  test 'menu notification stays centered throughout its entrance animation on mobile' do
    _venue, table, product = build_venue
    page.current_window.resize_to(375, 812)
    visit new_table_order_path(table)
    find('.customer-add-button').click
    assert_selector '.customer-menu-toast', text: 'adicionado ao pedido'
    centered = page.evaluate_script(<<~JS)
      new Promise(resolve => {
        const toast = document.querySelector('.customer-menu-toast');
        const samples = [];
        const sample = () => {
          const r = toast.getBoundingClientRect();
          samples.push(Math.abs((r.left + r.right) / 2 - document.documentElement.clientWidth / 2) < 2 && r.left >= 0 && r.right <= document.documentElement.clientWidth);
        };
        sample();
        setTimeout(sample, 80);
        setTimeout(() => { sample(); resolve(samples.every(Boolean)); }, 250);
      })
    JS
    assert centered, 'Toast must remain centered before, during and after the entrance animation'
    find('.customer-remove-button').click
    assert_selector '.customer-menu-toast', text: 'removido do pedido'
  end

  test 'login error notification fits the mobile screen and is centered' do
    venue, = build_venue
    manager = venue_user(venue)
    page.current_window.resize_to(375, 812)
    visit login_path
    fill_in 'Email', with: manager.email
    fill_in 'Palavra-passe', with: 'Incorrect-password'
    click_on 'Entrar'
    assert_text 'Utilizador/email ou palavra-passe inválidos'
    assert_selector '.app-flash-stack .flash'
    assert page.evaluate_script(<<~JS)
      (() => {
        const r = document.querySelector('.app-flash-stack .flash').getBoundingClientRect();
        return Math.abs((r.left + r.right) / 2 - document.documentElement.clientWidth / 2) < 2 && r.left >= 0 && r.right <= document.documentElement.clientWidth;
      })()
    JS
  end
end
