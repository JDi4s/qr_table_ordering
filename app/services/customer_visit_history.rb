# Groups only the authenticated customer's orders for one table.
# New visits end when the table closes. Historical orders without a visit keep
# their existing timestamp grouping, never a browser timer.
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
    legacy, explicit = orders.partition { |order| !order.respond_to?(:table_visit_id) || order.table_visit_id.nil? }
    legacy.sort_by { |order| [order.created_at, order.id] }.each do |order|
      visit = visits.last
      if visit.nil? || (visit.ended_at && order.created_at >= visit.ended_at)
        visit = Visit.new(orders: [])
        visits << visit
      end
      visit.orders << order
      visit.ended_at = end_time(visit.orders)
    end

    explicit.group_by(&:table_visit_id).each_value do |group|
      sorted = group.sort_by { |order| [order.created_at, order.id] }
      visits << Visit.new(orders: sorted, ended_at: sorted.first.table_visit.closed_at)
    end
    visits.sort_by! { |visit| [visit.started_at, visit.orders.first.id] }

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
