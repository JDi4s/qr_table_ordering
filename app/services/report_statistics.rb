require 'set'

# These figures are receipts, attributed to the person who recorded the payment.
class ReportStatistics
  attr_reader :total, :payments_count, :quantity, :by_method, :staff, :products

  def initialize(payments)
    @total = 0.to_d
    @payments_count = @quantity = 0
    @order_ids = Set.new
    @by_method = Hash.new(0.to_d)
    @staff = {}
    @products = {}
    @hours = Hash.new(0.to_d)
    @days = Hash.new(0.to_d)
    @months = Hash.new(0.to_d)
    payments.respond_to?(:find_each) ? payments.find_each(batch_size: 500) { |payment| add(payment) } : payments.each { |payment| add(payment) }
  end

  def orders_count
    @order_ids.size
  end

  def average
    orders_count.zero? ? 0.to_d : total / orders_count
  end

  def top_products(metric)
    products.values.sort_by { |row| [-row.fetch(metric), row[:name]] }.first(10)
  end

  def series(first, last, group)
    case group
    when 'hour'
      24.times.map { |hour| { label: format('%02d:00', hour), amount: @hours[hour] } }
    when 'month'
      rows = []
      month = first.beginning_of_month
      while month <= last
        rows << { label: month.strftime('%m/%Y'), amount: @months[month] }
        month = month.next_month
      end
      rows
    else
      (first..last).map { |day| { label: day.strftime('%d/%m/%Y'), amount: @days[day] } }
    end
  end

  private

  def add(payment)
    amount = payment.amount.to_d
    @total += amount
    @payments_count += 1
    @order_ids.add(payment.order_id)
    @by_method[payment.payment_method] += amount
    user = payment.user
    @staff[payment.user_id] ||= { id: payment.user_id, name: user.name.presence || user.login_identifier, amount: 0.to_d, count: 0 }
    @staff[payment.user_id][:amount] += amount
    @staff[payment.user_id][:count] += 1
    date = payment.paid_at.in_time_zone
    @hours[date.hour] += amount
    @days[date.to_date] += amount
    @months[date.to_date.beginning_of_month] += amount
    payment.payment_items.each do |item|
      @quantity += item.quantity
      key = item.order_item.menu_item_id || "order_item_#{item.order_item_id}"
      @products[key] ||= { name: item.order_item.display_name, quantity: 0, amount: 0.to_d }
      @products[key][:quantity] += item.quantity
      @products[key][:amount] += item.amount.to_d
    end
  end
end
