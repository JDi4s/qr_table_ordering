# Groups only the authenticated customer's orders for one table.
# Visit boundaries are derived from business timestamps, never a browser timer.
class CustomerVisitHistory
  GRACE_PERIOD = 2.hours
  HISTORY_PERIOD = 24.hours

  Visit = Struct.new(:orders, :ended_at, keyword_init: true) do
    def started_at
      orders.first.created_at
    end
  end

  attr_reader :current_visit, :previous_visits

  def initialize(orders, now: Time.current)
    visits = []
    orders.sort_by { |order| [order.created_at, order.id] }.each do |order|
      visit = visits.last
      if visit.nil? || (visit.ended_at && order.created_at >= visit.ended_at)
        visit = Visit.new(orders: [])
        visits << visit
      end
      visit.orders << order
      visit.ended_at = end_time(visit.orders)
    end

    @current_visit = visits.last if visits.last && (visits.last.ended_at.nil? || now < visits.last.ended_at)
    @previous_visits = visits.reverse.reject { |visit| visit.equal?(@current_visit) }
      .select { |visit| visit.ended_at && visit.ended_at <= now && now < visit.ended_at + HISTORY_PERIOD }
  end

  private

  def end_time(orders)
    completed_at = orders.map do |order|
      if order.denied?
        order.cancelled_at || order.updated_at
      elsif order.served? && order.paid?
        [order.served_at || order.updated_at, order.paid_at].max
      end
    end
    return if completed_at.any?(&:nil?)

    completed_at.max + GRACE_PERIOD
  end
end
