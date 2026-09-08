require 'test_helper'
class ConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  setup { @venue, @table, @product = build_venue(limit: 2) }
  teardown do
    @venue.service_calls.delete_all
    @venue.orders.destroy_all
    @venue.users.delete_all
    @venue.menu_items.delete_all
    @venue.categories.delete_all
    @venue.tables.delete_all
    @venue.destroy!
  end

  test 'two parallel creates cannot exceed the last available table slot' do
    results = [2, 3].map do |number|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          Table.create!(establishment_id: @venue.id, number: number)
          :created
        rescue ActiveRecord::RecordInvalid
          :limited
        end
      end
    end.map(&:value)
    assert_equal [:created, :limited], results.sort
    assert_equal 2, @venue.tables.where(active: true).count
  end

  test 'parallel service calls produce one pending record' do
    ids = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection { ServiceCall.request_for!(Table.find(@table.id)).id }
      end
    end.map(&:value)
    assert_equal 1, ids.uniq.length
    assert_equal 1, @table.service_calls.count
  end
end
