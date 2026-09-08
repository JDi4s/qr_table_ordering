require 'test_helper'
class ConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  setup { @venue, @table, @product = build_venue(limit: 2) }
  teardown do
    ServiceCall.where(table_id: @venue.tables.select(:id)).delete_all
    Order.where(table_id: @venue.tables.select(:id)).destroy_all
    User.where(establishment_id: @venue.id).delete_all
    MenuItem.where(category_id: @venue.categories.select(:id)).delete_all
    Category.where(establishment_id: @venue.id).delete_all
    Table.where(establishment_id: @venue.id).delete_all
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
