require 'application_system_test_case'

class GoogleReviewsSystemTest < ApplicationSystemTestCase
  test 'manager sees compact Google review settings on mobile' do
    venue, = build_venue
    venue.update!(google_reviews_enabled: true, google_review_url: 'https://g.page/r/test/review')
    manager = venue_user(venue)

    page.current_window.resize_to(375, 812)
    visit login_path
    fill_in 'Email', with: manager.email
    fill_in 'Palavra-passe', with: 'Test-password-123'
    click_on 'Entrar'
    assert_current_path staff_orders_path, wait: 10
    assert_no_button 'Entrar'
    visit edit_staff_settings_path

    assert_selector '.service-status-card'
    assert_equal 'Configurado', find('.google-review-settings-status.is-ready', visible: :all).text(:all)
    find('.google-review-settings summary').click
    assert_field 'Link para avaliações', with: 'https://g.page/r/test/review'
    assert_link 'Testar ligação', href: 'https://g.page/r/test/review'
    page.save_screenshot(Rails.root.join('tmp/screenshots/google-review-settings-mobile.png'))
  end

  test 'customer can dismiss invitation and Turbo updates do not restore it' do
    venue, table, product = build_venue
    venue.update!(google_reviews_enabled: true, google_review_url: 'https://g.page/r/test/review')
    page.current_window.resize_to(375, 812)
    visit new_table_order_path(table)
    find('.customer-product-card', text: product.name).click
    click_on 'Rever pedido'
    click_on 'Enviar pedido'
    assert_text 'Os meus pedidos'
    assert_selector 'turbo-cable-stream-source[connected]', visible: :all
    assert_selector '.google-review-invitation'
    assert_text 'Como foi?'
    assert_selector '.google-review-launcher'
    assert_no_selector '.google-review-panel'
    assert page.evaluate_script("(() => { const r = document.querySelector('.google-review-launcher').getBoundingClientRect(); const x = document.querySelector('.google-review-dismiss').getBoundingClientRect(); const b = document.querySelector('.google-review-open').getBoundingClientRect(); return Math.abs((r.top + r.bottom) / 2 - innerHeight / 2) < 2 && r.width < 200 && x.right <= b.left + 1 })()")
    find('.google-review-open').click
    assert_text 'Como foi a tua experiência?'
    assert_link 'Avaliar no Google', href: 'https://g.page/r/test/review'
    find('button[aria-label="Recolher convite de avaliação"]').click
    assert_no_selector '.google-review-panel'
    assert_selector '.google-review-launcher'
    assert_selector '.google-review-invitation', count: 1
    assert_no_selector '#my_orders .google-review-invitation'
    assert_equal 'fixed', page.evaluate_script("getComputedStyle(document.querySelector('.google-review-invitation')).position")
    assert page.evaluate_script("(() => { const r = document.querySelector('.google-review-invitation').getBoundingClientRect(); return r.top >= 0 && r.right <= innerWidth && r.bottom <= innerHeight })()")
    page.execute_script("document.body.style.minHeight = '2000px'; window.scrollTo(0, 500)")
    assert page.evaluate_script("(() => { const r = document.querySelector('.google-review-invitation').getBoundingClientRect(); return Math.abs((r.top + r.bottom) / 2 - innerHeight / 2) < 2 })()")
    page.execute_script('window.scrollTo(0, 0)')
    page.save_screenshot(Rails.root.join('tmp/screenshots/google-review-invitation.png'))
    find('button[aria-label="Fechar convite de avaliação"]').click
    assert_no_selector '.google-review-invitation'
    table.orders.last.finalize_review!
    assert_text 'Aceite'
    assert_no_selector '.google-review-invitation'
    visit my_table_orders_path(table)
    assert_no_selector '.google-review-invitation'
    page.save_screenshot(Rails.root.join('tmp/screenshots/google-review-dismissed.png'))
  end
end
