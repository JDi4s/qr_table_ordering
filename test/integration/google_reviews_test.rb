require 'test_helper'

class GoogleReviewsTest < ActionDispatch::IntegrationTest
  setup do
    @venue, @table, @product = build_venue
    @manager = venue_user(@venue)
    @url = 'https://g.page/r/test/review'
  end

  test 'module defaults off and only administrator can enable it' do
    assert_not @venue.google_reviews_enabled?
    sign_in(@manager)
    patch staff_settings_path, params: { establishment: { google_reviews_enabled: '1', google_review_url: @url } }
    assert_not @venue.reload.google_reviews_enabled?
    assert_nil @venue.google_review_url
    get edit_staff_settings_path
    assert_select '#establishment_google_review_url', count: 0

    owner = User.create!(email: "reviews-owner-#{SecureRandom.hex(4)}@example.com", password: 'Test-password-123', role: 'platform_admin')
    sign_in(owner)
    patch admin_establishment_path(@venue), params: { establishment: { google_reviews_enabled: '1' } }
    assert_response :see_other
    assert @venue.reload.google_reviews_enabled?
  end

  test 'manager saves clears and validates link while staff cannot modify it' do
    @venue.update!(google_reviews_enabled: true)
    sign_in(@manager)
    patch staff_settings_path, params: { establishment: { google_review_url: @url } }
    assert_equal @url, @venue.reload.google_review_url
    patch staff_settings_path, params: { establishment: { google_review_url: 'https://google.com.evil.example/review' } }
    assert_response :unprocessable_entity
    assert_equal @url, @venue.reload.google_review_url
    sign_in(venue_user(@venue, role: 'staff'))
    patch staff_settings_path, params: { establishment: { google_review_url: 'https://google.com/other' } }
    assert_equal @url, @venue.reload.google_review_url
    sign_in(@manager)
    patch staff_settings_path, params: { establishment: { google_review_url: '' } }
    assert_nil @venue.reload.google_review_url
  end

  test 'invitation appears on pending customer order and disappears when disabled or denied' do
    get new_table_order_path(@table)
    post review_table_orders_path(@table), params: { order: { items: { @product.id.to_s => '1' } } }
    quote = response.body[/name="quote" value="([^"]+)"/, 1]
    assert quote.present?
    @venue.update!(google_reviews_enabled: true, google_review_url: @url)
    post table_orders_path(@table), params: { quote: CGI.unescapeHTML(quote) }
    follow_redirect!
    assert_select '.google-review-invitation', count: 1
    assert_select 'a.google-review-link[href=?][target="_blank"][rel="noopener noreferrer"]', @url
    assert @venue.orders.last.pending?
    @venue.update!(google_reviews_enabled: false)
    get my_table_orders_path(@table)
    assert_select '.google-review-invitation', count: 0
    @venue.update!(google_reviews_enabled: true)
    @venue.orders.last.reject!(nil, customer: true)
    get my_table_orders_path(@table)
    assert_select '.google-review-invitation', count: 0
  end

  test 'rejects unsafe and non Google URLs' do
    ['javascript:alert(1)', 'http://google.com/review', 'https://google.com@evil.example/', 'https://google.com.evil.example/', 'https://evil.example/', 'https://google.com:8443/', 'https://user:pass@google.com/', 'not a URL'].each do |url|
      @venue.google_review_url = url
      assert_not @venue.valid?, url
    end
    @venue.google_review_url = @url
    assert @venue.valid?
  end
end
