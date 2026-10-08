require 'test_helper'

class GoogleReviewStatisticsTest < ActiveSupport::TestCase
  test 'Lisbon date boundaries and reporting start distinguish zero from unrecorded periods' do
    venue, = build_venue
    venue.update!(google_review_tracking_started_at: Time.zone.parse('2026-10-01 09:00'))
    venue.google_review_clicks.create!(visitor_digest: 'a' * 64, created_at: Time.zone.parse('2026-09-30 23:30 UTC'))
    venue.google_review_clicks.create!(visitor_digest: 'b' * 64, created_at: Time.zone.parse('2026-10-02 00:00'))
    stats = GoogleReviewStatistics.new(establishment: venue, from: Date.new(2026, 10, 1), to: Date.new(2026, 10, 1))
    assert_equal [1, 1], stats.rows.map(&:last)
    before = GoogleReviewStatistics.new(establishment: venue, from: Date.new(2026, 9, 30), to: Date.new(2026, 9, 30))
    assert_equal ['Sem registo', 'Sem registo'], before.rows.map(&:last)
    after = GoogleReviewStatistics.new(establishment: venue, from: Date.new(2026, 10, 3), to: Date.new(2026, 10, 3))
    assert_equal [0, 0], after.rows.map(&:last)
    period = ReportPeriod.new({ view: 'custom', from: '2026-10-01', to: '2026-10-02' }, today: Date.new(2026, 10, 8))
    data = ReportExtract.new(establishment: venue, period: period, employee: venue_user(venue)).data
    assert_equal [2, 2], data[:sections].find { |s| s[:title] == 'Avaliações Google' }[:rows].map(&:last)
    assert_includes data[:notes].last, 'sem filtro por funcionário'
  end
end
