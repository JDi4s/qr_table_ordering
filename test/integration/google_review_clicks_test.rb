require 'test_helper'
require 'csv'

class GoogleReviewClicksTest < ActionDispatch::IntegrationTest
  setup do
    @venue, @table, @product = build_venue
    @venue.update!(plan: 'management', google_reviews_enabled: true, google_review_url: 'https://g.page/r/test/review',
                   google_review_tracking_started_at: 2.days.ago)
    TableVisit.activate_for!(@table)
  end

  def place_order(client = self, table = @table, product = @product)
    client.get new_table_order_path(table)
    client.post review_table_orders_path(table), params: { order: { items: { product.id.to_s => '1' } } }
    quote = Nokogiri::HTML(client.response.body).at_css('input[name="quote"]')['value']
    client.post table_orders_path(table), params: { quote: quote }
  end

  test 'explicit clicks open the configured Google link and count repeated browsers once' do
    place_order
    assert_no_difference 'GoogleReviewClick.count' do
      get my_table_orders_path(@table)
      get my_table_orders_path(@table)
    end
    2.times do
      assert_difference 'GoogleReviewClick.count', 1 do
        post table_google_review_clicks_path(@table), params: { url: 'https://evil.example/' }
      end
      assert_redirected_to @venue.google_review_url
      assert_response :see_other
    end
    other_browser = open_session
    place_order(other_browser)
    other_browser.post table_google_review_clicks_path(@table)
    assert_equal 3, @venue.google_review_clicks.count
    assert_equal 2, @venue.google_review_clicks.distinct.count(:visitor_digest)
    assert_match(/\A[0-9a-f]{64}\z/, @venue.google_review_clicks.first.visitor_digest)
  end

  test 'unknown sessions foreign tables and disabled links cannot create clicks' do
    assert_no_difference 'GoogleReviewClick.count' do
      post table_google_review_clicks_path(@table)
      assert_response :not_found
    end
    place_order
    other, table, = build_venue
    other.update!(google_reviews_enabled: true, google_review_url: @venue.google_review_url)
    assert_no_difference 'GoogleReviewClick.count' do
      post table_google_review_clicks_path(table)
      assert_response :not_found
      @venue.update!(google_reviews_enabled: false)
      post table_google_review_clicks_path(@table)
      assert_response :not_found
    end
  end

  test 'dashboard CSV and PDF include the selected period without leaking another venue' do
    @venue.google_review_clicks.create!(visitor_digest: 'a' * 64, created_at: Date.current.beginning_of_day)
    @venue.google_review_clicks.create!(visitor_digest: 'a' * 64, created_at: Time.current)
    @venue.google_review_clicks.create!(visitor_digest: 'b' * 64, created_at: 1.day.ago)
    other, = build_venue
    other.google_review_clicks.create!(visitor_digest: 'c' * 64, created_at: Time.current)
    sign_in(venue_user(@venue))
    get staff_reports_path(view: 'day', date: Date.current.iso8601)
    assert_select '.report-google-reviews .report-stat strong', text: '2', count: 1
    assert_select '.report-google-reviews .report-stat strong', text: '1', count: 1
    get export_staff_reports_path(view: 'day', date: Date.current.iso8601)
    assert_response :success
    assert response.body.start_with?("\uFEFF")
    rows = CSV.parse(response.body.delete_prefix("\uFEFF"), col_sep: ';')
    assert_includes rows, ['Cliques em Avaliar no Google', '2']
    assert_includes rows, ['Navegadores distintos que clicaram', '1']
    get pdf_staff_reports_path(view: 'day', date: Date.current.iso8601)
    assert_response :success
    assert_equal 'application/pdf', response.media_type
    assert response.body.start_with?('%PDF')
    get staff_reports_path(view: 'custom', from: (Date.current - 1).iso8601, to: Date.current.iso8601)
    assert_select '.report-google-reviews .report-stat strong', text: '3', count: 1
    assert_select '.report-google-reviews .report-stat strong', text: '2', count: 1
  end
end
