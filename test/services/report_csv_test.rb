require 'test_helper'
require 'csv'

class ReportCsvTest < ActiveSupport::TestCase
  test 'full extract exports all sections and payments with Excel compatible accents separators and quoting' do
    venue, table, product = build_venue
    venue.update!(name: 'Café; "São João"', google_review_tracking_started_at: 1.day.ago)
    product.update!(name: '=HYPERLINK("https://example.com")')
    user = venue_user(venue)
    order = build_order(table, product)
    order.finalize_review!
    order.mark_paid!(user)
    venue.google_review_clicks.create!(visitor_digest: 'a' * 64)
    period = ReportPeriod.new({ view: 'day', date: Date.current.iso8601 })
    data = ReportExtract.new(establishment: venue, period: period).data
    document = ReportCsv.new(data).render
    assert document.start_with?("\uFEFF")
    assert_includes document, "\r\n"
    rows = CSV.parse(document.delete_prefix("\uFEFF"), col_sep: ';')
    assert_includes rows, ['Estabelecimento', venue.name]
    assert_includes rows, ['Faturação recebida', '30,00 €']
    assert_includes rows, ['Cliques em Avaliar no Google', '1']
    data[:sections].each { |section| assert_includes rows, [section[:title]] }
    assert_includes rows, ['Pagamentos detalhados']
    assert_includes rows, data[:payment_rows].first
    assert rows.flatten.compact.any? { |value| value.start_with?("'=HYPERLINK") }
    assert_not rows.flatten.compact.any? { |value| value.start_with?('=HYPERLINK') }
  end
end
