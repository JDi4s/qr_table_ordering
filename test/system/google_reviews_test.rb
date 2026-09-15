require 'application_system_test_case'

class GoogleReviewsSystemTest < ApplicationSystemTestCase
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
    click_on 'Fechar convite de avaliação'
    assert_no_selector '.google-review-invitation'
    table.orders.last.finalize_review!
    assert_text 'Aceite'
    assert_no_selector '.google-review-invitation'
    visit my_table_orders_path(table)
    assert_no_selector '.google-review-invitation'
    page.save_screenshot(Rails.root.join('tmp/screenshots/google-review-dismissed.png'))
  end
end
