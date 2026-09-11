require 'set'

class ReportStatistics
  attr_reader :total, :payments_count, :by_method, :staff, :products

  def initialize(payments)
    @total = 0.to_d
    @payments_count = 0
    @order_ids = Set.new
    @by_method = Hash.new(0.to_d)
    @staff = {}
    @products = {}
    @days = Hash.new(0.to_d)
    @months = Hash.new(0.to_d)
    payments.respond_to?(:find_each) ? payments.find_each(batch_size: 500) { |payment| add(payment) } : payments.each { |payment| add(payment) }
  end

  def orders_count = @order_ids.size
  def average = orders_count.zero? ? 0.to_d : total / orders_count

  def series(first, last, view)
    case view
    when 'month', 'last_7_days'
      (first..last).map { |day| { label: day.strftime('%d'), amount: @days[day] } }
    when 'year'
      (1..12).map do |month|
        date = Date.new(first.year, month, 1)
        { label: date.strftime('%b'), amount: @months[date] }
      end
    when 'lifetime'
      years = (@months.keys.map(&:year) + [last.year]).uniq.sort
      years.map { |year| { label: year.to_s, amount: @months.select { |date, _| date.year == year }.values.sum } }
    else
      [{ label: first.strftime('%d/%m'), amount: @days[first] }]
    end
  end

  def top_products(metric, limit: 10)
    products.values.sort_by { |row| [-row.fetch(metric), row[:name]] }.first(limit)
  end

  private

  def add(payment)
    amount = payment.amount.to_d
    @total += amount
    @payments_count += 1
    @order_ids.add(payment.order_id)
    @by_method[payment.payment_method] += amount
    user = payment.user
    @staff[payment.user_id] ||= { id: payment.user_id, name: user.display_identity, amount: 0.to_d, count: 0 }
    @staff[payment.user_id][:amount] += amount
    @staff[payment.user_id][:count] += 1
    date = payment.paid_at.in_time_zone.to_date
    @days[date] += amount
    @months[date.beginning_of_month] += amount
    payment.payment_items.each do |item|
      key = item.order_item.menu_item_id || "order_item_#{item.order_item_id}"
      @products[key] ||= { name: item.order_item.display_name, quantity: 0, amount: 0.to_d }
      @products[key][:quantity] += item.quantity
      @products[key][:amount] += item.amount.to_d
    end
  end
end
