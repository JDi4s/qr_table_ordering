require 'test_helper'
require 'minitest/mock'

class TableVisitTest < ActiveSupport::TestCase
  setup do
    @venue, @table, @product = build_venue
    @manager = venue_user(@venue)
  end

  test 'repeated QR openings share one pending visit and notify only once' do
    notices = []
    StaffPushNotifier.stub(:notify_table_activation, ->(visit) { notices << visit.id }) do
      first = TableVisit.request_for!(@table)
      assert first.waiting?
      assert_equal first.id, TableVisit.request_for!(Table.find(@table.id)).id
      assert_equal [first.id], notices
      assert_equal 1, @table.table_visits.count
      assert_broadcasts("table_activation_#{@venue.id}", 0) { TableVisit.request_for!(@table) }
      TableVisit.activate_for!(@table)
      assert first.reload.open?
      assert_equal [first.id], notices
      assert_equal first.id, TableVisit.request_for!(@table).id
    end
  end

  test 'partial payments and another outstanding order keep the visit open' do
    visit = TableVisit.activate_for!(@table)
    first = build_order(@table, @product)
    second = build_order(@table, @product)
    [first, second].each { |order| order.update!(table_visit: visit); order.finalize_review! }
    first.pay_item!(first.order_items.second.id, 1, @manager)
    assert visit.reload.open?
    first.mark_paid!(@manager)
    assert visit.reload.open?
    assert_raises(Order::InvalidTransition) { TableVisit.close_for!(@table) }
    second.mark_paid!(@manager)
    assert visit.reload.closed_at
    assert_not visit.open?
    assert_not_equal visit.id, TableVisit.request_for!(@table).id
  end

  test 'empty visit can close manually and correcting a payment never reopens access' do
    empty = TableVisit.activate_for!(@table)
    TableVisit.close_for!(@table)
    assert empty.reload.closed_at
    visit = TableVisit.activate_for!(@table)
    order = build_order(@table, @product)
    order.update!(table_visit: visit)
    order.finalize_review!
    order.mark_paid!(@manager)
    order.payments.last.void!(@manager, reason: 'Método errado')
    assert visit.reload.closed_at
    assert_not order.reload.paid?
    order.mark_paid!(@manager)
    assert visit.reload.closed_at
  end

  test 'explicit visits leave current history immediately and retain only customer orders for 24 hours' do
    visit = TableVisit.activate_for!(@table)
    order = build_order(@table, @product)
    order.update!(table_visit: visit)
    history = CustomerVisitHistory.new([order])
    assert_equal [order], history.current_visit.orders
    order.finalize_review!
    order.mark_paid!(@manager)
    history = CustomerVisitHistory.new([order.reload])
    assert_nil history.current_visit
    assert_equal [order], history.previous_visits.first.orders
    assert_empty CustomerVisitHistory.new([order], now: visit.reload.closed_at + 24.hours).previous_visits
  end
end
