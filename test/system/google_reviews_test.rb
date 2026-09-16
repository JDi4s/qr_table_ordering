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
    visit edit_staff_settings_path

    assert_selector '.service-status-card'
    assert_selector '.google-review-settings-status.is-ready', text: 'Configurado'
    assert_field 'Link para avaliações', with: 'https://g.page/r/test/review'
    assert_link 'Testar ligação', href: 'https://g.page/r/test/review'
    page.save_screenshot(Rails.root.join('tmp/screenshots/google-review-settings-mobile.png'))
  end

  test 'customer can dismiss invitation and Turbo updates do not restore it' do
    venue, table, product = build_venue
    venue.update!(google_reviews_enabled: true, google_review_url: 'https://g.page/r/test/review')
    visit new_table_order_path(table)
    find('.customer-product-card', text: product.name).click
    click_on 'Rever pedido'
    click_on 'Enviar pedido'
    assert_text 'Os meus pedidos'
    assert_selector 'turbo-cable-stream-source[connected]', visible: :all
    assert_selector '.google-review-invitation'
    assert_text 'Já conheces o nosso espaço?'
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
