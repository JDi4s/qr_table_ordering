require 'csv'

class Staff::ReportsController < Staff::BaseController
  before_action :require_manager
  rescue_from ReportPeriod::Invalid, with: :invalid_filter

  def index
    @report_tab = params[:tab] == 'cash' ? 'cash' : 'statistics'
    @report_tab == 'cash' ? load_daily_report : load_statistics
  end

  def export
    if params[:tab] == 'cash'
      first = last = cash_date
    else
      period = ReportPeriod.new(params)
      first, last = period.from, period.to
      load_employee
    end
    payments = report_payments(first, last, employee: @employee).includes(order: :table)
    csv = CSV.generate(headers: true) do |output|
      output << ['Data', 'Hora', 'Pedido', 'Mesa', 'Funcionário', 'Método', 'Valor']
      payments.find_each(batch_size: 500) do |payment|
        local = payment.paid_at.in_time_zone
        output << [local.to_date, local.strftime('%H:%M'), payment.order_id, payment.order.table.number,
                   csv_text(payment.user.name.presence || payment.user.login_identifier),
                   helpers.payment_method_label(payment.payment_method), payment.amount.to_s('F')]
      end
    end
    send_data csv, filename: "relatorio_#{first}_#{last}.csv", type: 'text/csv; charset=utf-8'
  end

  def close
    load_daily_report
    if @closure
      redirect_to staff_reports_path(tab: 'cash', date: @date), alert: 'Este dia já foi fechado.'
      return
    end
    @closure = current_establishment.cash_closures.create!(
      user: current_user, business_date: @date, total_amount: @statistics.total,
      payments_count: @statistics.payments_count,
      payment_breakdown: @statistics.by_method.transform_values(&:to_s), closed_at: Time.current
    )
    AuditLogger.record(user: current_user, action: 'cash_closed', record: @closure,
                      metadata: { business_date: @date.to_s, total: @statistics.total.to_s })
    redirect_to staff_reports_path(tab: 'cash', date: @date), notice: "Caixa de #{@date.strftime('%d/%m/%Y')} fechado."
  end

  private

  def load_statistics
    @period = ReportPeriod.new(params)
    load_employee
    @employees = current_establishment.users.order(:name, :id)
    @statistics = ReportStatistics.new(report_payments(@period.from, @period.to, employee: @employee))
    @previous = @period.comparing? ? ReportStatistics.new(report_payments(@period.compare_from, @period.compare_to, employee: @employee)) : ReportStatistics.new([])
    @filter_params = @period.to_params.merge(employee_id: @employee&.id)
    current_series = @statistics.series(@period.from, @period.to, @period.group)
    previous_series = @period.comparing? ? @previous.series(@period.compare_from, @period.compare_to, @period.group) : []
    @chart_rows = [current_series.size, previous_series.size].max.times.map { |index| { current: current_series[index], previous: previous_series[index] } }
    @staff_rows = (@statistics.staff.keys | @previous.staff.keys).map do |id|
      current = @statistics.staff[id]
      previous = @previous.staff[id]
      { id: id, name: (current || previous)[:name], amount: current ? current[:amount] : 0.to_d,
        count: current ? current[:count] : 0, previous: previous ? previous[:amount] : 0.to_d,
        previous_count: previous ? previous[:count] : 0 }
    end.sort_by { |row| [-row[:amount], row[:name], row[:id]] }
  end

  def load_daily_report
    @date = cash_date
    @statistics = ReportStatistics.new(report_payments(@date, @date))
    @closure = current_establishment.cash_closures.includes(:user).find_by(business_date: @date)
    @unpaid_tables = current_establishment.tables.joins(:orders).merge(Order.unpaid).distinct.order(:number)
  end

  def report_payments(first, last, employee: nil)
    scope = current_establishment.payments.where(paid_at: first.beginning_of_day...(last + 1).beginning_of_day).includes(:user, payment_items: { order_item: :menu_item })
    employee ? scope.where(user_id: employee.id) : scope
  end

  def load_employee
    return if params[:employee_id].blank?
    @employee = current_establishment.users.find_by(id: params[:employee_id])
    raise ReportPeriod::Invalid, 'Escolha um funcionário deste estabelecimento.' unless @employee
  end

  def cash_date
    return Date.current if params[:date].blank?
    date = Date.iso8601(params[:date].to_s)
    raise ArgumentError unless date.year.between?(1900, 9999)
    date
  rescue ArgumentError
    raise ReportPeriod::Invalid, 'Indique um dia válido para consultar a caixa.'
  end

  def invalid_filter(error)
    redirect_to staff_reports_path(tab: params[:tab] == 'cash' || action_name == 'close' ? 'cash' : 'statistics'), alert: error.message
  end

  def csv_text(value)
    value.to_s.match?(/\A\s*[=+@-]/) ? "'#{value}" : value
  end
end
