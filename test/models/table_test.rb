require 'test_helper'
class TableTest < ActiveSupport::TestCase
  setup { @venue, @table, @product = build_venue(limit: 1) }
  test 'quota applies to creation and reactivation but not reprinting' do
    assert_raises(ActiveRecord::RecordInvalid) { @venue.tables.create!(number: 2) }
    2.times { assert_includes @table.qr_code, '<svg' }
    assert_equal 1, @venue.tables.where(active: true).count
    @table.update!(active: false)
    second = @venue.tables.create!(number: 2)
    assert_raises(ActiveRecord::RecordInvalid) { @table.update!(active: true) }
    @venue.with_lock { @venue.update!(table_limit: 2) }
    @table.reload.update!(active: true)
    assert_equal 2, @venue.tables.where(active: true).count
  end
  test 'numbers unique only within venue and limits cannot shrink below usage' do
    other, other_table, = build_venue
    assert_equal @table.number, other_table.number
    assert_not @venue.tables.new(number: 1).valid?
    assert_not @venue.update(table_limit: 0)
  end
  test 'configured public origin is used in QR URLs' do
    old = Rails.configuration.x.public_url
    Rails.configuration.x.public_url = 'https://mesas.example.com'
    assert_equal "https://mesas.example.com/tables/#{@table.qr_token}/orders/new", @table.ordering_url
  ensure
    Rails.configuration.x.public_url = old
  end
end
