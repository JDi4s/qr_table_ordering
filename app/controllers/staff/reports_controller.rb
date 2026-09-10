require 'csv'

class Staff::ReportsController < Staff::BaseController
  before_action :require_manager
  rescue_from ReportPeriod::Invalid, with: :invalid_filter

  ANALYSES = %w[employees products revenue orders].freeze
  METRICS = {
    'employees' => %w[calls tables sales],
    'products' => %w[top bottom revenue],
    'revenue' => %w[total tables employees average],
    'orders' => %w[total served cancelled]
  }.freeze

  def index
    @report_tab = params[:tab] == 'cash' ? 'cash' : 'statistics'
    @report_tab == 'cash' ? load_daily_report : load_statistics
  end

  def export
    period = params[:tab] == 'cash' ? nil : ReportPeriod.new(params)
    first = period ? period.from : cash_date
    last = period ? period.to : first
    payments = report_payments(first, last).includes(order: :table)
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
    @analysis = ANALYSES.include?(params[:analysis].to_s) ? params[:analysis].to_s : 'revenue'
    @metric = METRICS.fetch(@analysis).include?(params[:metric].to_s) ? params[:metric].to_s : METRICS.fetch(@analysis).first
    @employees = current_establishment.users.order(:name, :id)
    load_employee
    @statistics = ReportStatistics.new(report_payments(@period.from, @period.to, employee: @employee))
    @previous = @period.comparing? ? ReportStatistics.new(report_payments(@period.compare_from, @period.compare_to, employee: @employee)) : nil
    @series = @statistics.series(@period.from, @period.to, @period.view)
    @previous_series = @previous&.series(@period.compare_from, @period.compare_to, @period.view) || []
    @chart_rows = @series.each_with_index.map { |point, index| point.merge(previous: @previous_series[index]&.fetch(:amount, 0.to_d)) }
    load_analysis_data
    @filter_params = @period.to_params.merge(tab: 'statistics', analysis: @analysis, metric: @metric, employee_id: @employee&.id)
  end

  def load_analysis_data
    @staff_rows = @statistics.staff.values.sort_by { |row| [-row[:amount], row[:name]] }
    @product_rows = @statistics.top_products(@metric == 'revenue' ? :amount : :quantity)
    @product_rows = @statistics.products.values.sort_by { |row| [row[:quantity], row[:name]] }.first(10) if @metric == 'bottom'
    @methods = @statistics.by_method.sort_by { |_, amount| -amount }
    @table_rows = statistics_by_table
    @employee_rows = statistics_by_employee
    @table_staff_rows = staff_table_rows
    @call_rows = service_call_rows
    @order_rows = order_rows
  end

  def statistics_by_table
    report_payments(@period.from, @period.to).joins(order: :table).group('tables.number').sum(:amount).sort_by { |_, amount| -amount }
  end

  def statistics_by_employee
    @statistics.staff.values.sort_by { |row| [-row[:amount], row[:name]] }
  end

  def staff_table_rows
    return [] unless defined?(AuditEvent) && current_establishment.respond_to?(:audit_events)
    events = current_establishment.audit_events.where(action: %w[order_served order_accepted], created_at: @period.from.beginning_of_day...(@period.to + 1).beginning_of_day).where.not(user_id: nil)
    events.group(:user_id).count.map do |id, count|
      user = @employees.find { |employee| employee.id == id }
      { name: user ? (user.name.presence || user.login_identifier) : 'Funcionário', value: count, label: 'mesas' }
    end.sort_by { |row| [-row[:value], row[:name]] }
  rescue ActiveRecord::StatementInvalid
    []
  end

  def service_call_rows
    calls = current_establishment.service_calls.where(created_at: @period.from.beginning_of_day...(@period.to + 1).beginning_of_day).where.not(assigned_user_id: nil)
    calls.group(:assigned_user_id).count.map do |id, count|
      user = @employees.find { |employee| employee.id == id }
      { name: user ? (user.name.presence || user.login_identifier) : 'Funcionário', count: count }
    end.sort_by { |row| [-row[:count], row[:name]] }
  end

  def order_rows
    scope = current_establishment.orders.where(created_at: @period.from.beginning_of_day...(@period.to + 1).beginning_of_day)
    { total: scope.count, served: scope.where(status: 'served').count, cancelled: scope.where(status: 'denied').count }
  end

  def load_daily_report
    @date = cash_date
    @statistics = ReportStatistics.new(report_payments(@date, @date))
    @closure = current_establishment.cash_closures.includes(:user).find_by(business_date: @date)
    @unpaid_tables = current_establishment.tables.joins(:orders).merge(Order.unpaid).distinct.order(:number)
  end

  def report_payments(first, last, employee: nil)
    scope = current_establishment.payments.where(paid_at: first.beginning_of_day... (last + 1).beginning_of_day).includes(:user, payment_items: { order_item: :menu_item })
    employee ? scope.where(user_id: employee.id) : scope
  end

  def load_employee
    return if params[:employee_id].blank?
    @employee = current_establishment.users.find_by(id: params[:employee_id])
    raise ReportPeriod::Invalid, 'Escolha um funcionário deste estabelecimento.' unless @employee
  end

  def cash_date
    return Date.current if params[:date].blank?
    Date.iso8601(params[:date].to_s)
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
