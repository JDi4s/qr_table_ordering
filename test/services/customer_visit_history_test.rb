require 'test_helper'

class CustomerVisitHistoryTest < ActiveSupport::TestCase
  Snapshot = Struct.new(:id, :created_at, :updated_at, :served_at, :paid_at, :cancelled_at, :status, keyword_init: true) do
    def denied?; status == 'denied'; end
    def served?; status == 'served'; end
    def paid?; paid_at.present?; end
  end

  def snapshot(id, created_at, completed_at: nil, status: 'served')
    Snapshot.new(id: id, created_at: created_at, updated_at: completed_at || created_at,
                 served_at: status == 'served' ? completed_at : nil,
                 paid_at: status == 'served' ? completed_at : nil,
                 cancelled_at: status == 'denied' ? completed_at : nil, status: status)
  end

  test 'a new order inside the grace period extends the same visit' do
    at = Time.zone.parse('2026-10-05 10:00')
    first = snapshot(1, at, completed_at: at + 30.minutes)
    second = snapshot(2, at + 2.hours, completed_at: at + 3.hours)
    history = CustomerVisitHistory.new([second, first], now: at + 4.hours)
    assert_equal [1, 2], history.current_visit.orders.map(&:id)
    assert_empty history.previous_visits
    assert_equal at + 5.hours, history.current_visit.ended_at
  end

  test 'a new order at the end boundary starts a separate visit' do
    at = Time.zone.parse('2026-10-05 10:00')
    first = snapshot(1, at, completed_at: at)
    second = snapshot(2, at + 2.hours, status: 'pending')
    history = CustomerVisitHistory.new([first, second], now: at + 2.hours)
    assert_equal [2], history.current_visit.orders.map(&:id)
    assert_equal [1], history.previous_visits.first.orders.map(&:id)
  end

  test 'pending and unpaid orders stay current regardless of age or count' do
    at = Time.zone.parse('2026-10-01 10:00')
    %w[pending accepted served].each do |status|
      first = snapshot(1, at, status: status)
      rest = (2..35).map { |id| snapshot(id, at + id.hours, completed_at: at + id.hours) }
      history = CustomerVisitHistory.new([first, *rest], now: at + 10.days)
      assert_equal 35, history.current_visit.orders.size
      assert_nil history.current_visit.ended_at
      assert_empty history.previous_visits
    end
  end

  test 'previous visits expire exactly 24 hours after ending' do
    at = Time.zone.parse('2026-10-05 10:00')
    order = snapshot(1, at, completed_at: at)
    assert CustomerVisitHistory.new([order], now: at + 2.hours - 1.second).current_visit
    history = CustomerVisitHistory.new([order], now: at + 2.hours)
    assert_nil history.current_visit
    assert_equal 1, history.previous_visits.size
    assert_equal 1, CustomerVisitHistory.new([order], now: at + 26.hours - 1.second).previous_visits.size
    assert_empty CustomerVisitHistory.new([order], now: at + 26.hours).previous_visits
  end

  test 'payment after service and cancellation set the grace period correctly' do
    at = Time.zone.parse('2026-10-05 10:00')
    order = snapshot(1, at, completed_at: at + 1.hour)
    order.paid_at = at + 3.hours
    cancelled = snapshot(2, at + 2.hours, completed_at: at + 4.hours, status: 'denied')
    history = CustomerVisitHistory.new([order, cancelled], now: at + 5.hours)
    assert_equal at + 6.hours, history.current_visit.ended_at
    assert_nil CustomerVisitHistory.new([], now: at).current_visit
  end
end
