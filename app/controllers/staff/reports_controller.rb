require 'csv'

class Staff::ReportsController < Staff::BaseController
  before_action :require_manager

  def index
    load_report
  end

  def export
    load_report
    csv = CSV.generate(headers: true) do |output|
      output << ['Data', 'Hora', 'Pedido', 'Mesa', 'Funcionário', 'Método', 'Valor']
      @payments.each do |payment|
        output << [payment.paid_at.to_date, payment.paid_at.strftime('%H:%M'), payment.order_id,
                   payment.order.table.number, payment.user.name.presence || payment.user.login_identifier,
                   payment_method_label(payment.payment_method), payment.amount.to_s('F')]
      end
    end
    send_data csv, filename: "relatorio_#{@start_date}_#{@end_date}.csv", type: 'text/csv; charset=utf-8'
  end

  def close
    load_report
    if @closure
      redirect_to staff_reports_path(date: @start_date), alert: 'Este dia já foi fechado.'
      return
    end

    @closure = current_establishment.cash_closures.create!(
      user: current_user,
      business_date: @start_date,
      total_amount: @total,
      payments_count: @payments.size,
      payment_breakdown: @by_method.transform_values(&:to_s),
      closed_at: Time.current
    )
    AuditLogger.record(user: current_user, action: 'cash_closed', record: @closure,
                      metadata: { business_date: @start_date.to_s, total: @total.to_s })
    redirect_to staff_reports_path(date: @start_date), notice: "Caixa de #{@start_date.strftime('%d/%m/%Y')} fechado."
  end

  private

  def load_report
    @start_date = Date.iso8601(params[:date].to_s)
  rescue ArgumentError
    @start_date = Date.current
  ensure
    @end_date = @start_date + 1.day
    @payments = current_establishment.payments
      .where(paid_at: @start_date.beginning_of_day...@end_date.beginning_of_day)
      .includes(:user, order: :table, payment_items: { order_item: :menu_item })
      .order(:paid_at)
    @total = @payments.sum(&:amount)
    @by_method = @payments.group_by(&:payment_method).transform_values { |payments| payments.sum(&:amount) }
    @staff_totals = @payments.group_by { |payment| payment.user.name.presence || payment.user.login_identifier }
      .transform_values { |payments| payments.sum(&:amount) }
      .sort_by { |name, amount| [-amount, name] }
    @product_totals = Hash.new(0.to_d)
    @payments.each do |payment|
      payment.payment_items.each { |item| @product_totals[item.order_item.display_name] += item.amount.to_d }
    end
    @product_totals = @product_totals.sort_by { |name, amount| [-amount, name] }.first(10)
    @unpaid_tables = current_establishment.tables.joins(:orders).merge(Order.unpaid).distinct.order(:number)
    @closure = current_establishment.cash_closures.find_by(business_date: @start_date)
  end
end
