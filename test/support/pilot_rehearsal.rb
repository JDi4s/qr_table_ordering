require 'action_dispatch/testing/integration'
require 'json'
require 'fileutils'

# Deliberately not loaded by `rails test`: this needs its own empty database.
class PilotRehearsal
  include Rails.application.routes.url_helpers

  def run
    raise 'Requires RAILS_ENV=test and mesa_rehearsal_test' unless Rails.env.test? && ActiveRecord::Base.connection_db_config.database == 'mesa_rehearsal_test'
    raise 'Rehearsal database must be empty' unless Establishment.count.zero?
    Rails.application.eager_load!
    @results = []
    @report = { kind: 'in-process Rails HTTP + PostgreSQL concurrency rehearsal', tables: 30,
                clients: 90, expected_orders: 180, connection_pool: ActiveRecord::Base.connection_pool.size,
                limitations: ['Not VPS capacity testing', 'No real network interruptions or push delivery', 'No browser/WebSocket timing measurement'] }
    begin
      prepare
      scenario('180 customer orders, 30 concurrent workers, sequential replay') do
        parallel(@clients.each_slice(3).to_a) do |clients|
          clients.each do |client|
            2.times do |round|
              session, table, note = client.values_at(:session, :table, :note)
              session.post review_table_orders_path(table), params: { order: { items: { @product.id.to_s => '2' }, note: "#{note}-#{round}" } }
              check(session.response.status == 200, 'Review failed')
              quote = Nokogiri::HTML(session.response.body).at_css('input[name="quote"]')&.[]('value')
              check(quote.present?, 'Missing signed quote')
              session.post table_orders_path(table), params: { quote: quote }
              check(session.response.status == 303, 'Submission failed')
              session.post table_orders_path(table), params: { quote: quote }
              check(session.response.status == 303, 'Replay failed')
            end
          end
        end
        check(@venue.orders.count == 180, 'Lost or duplicated orders')
        check(@venue.orders.sum(:total) == 1800, 'Wrong provisional total')
        check(@venue.orders.distinct.count(:customer_token) == 90, 'Customer identity mixed')
        check(@venue.orders.pluck(:note).uniq.size == 180, 'Notes lost')
      end

      scenario('Customer visibility and repeated assistance calls') do
        parallel(@clients.each_slice(3).to_a) do |clients|
          clients.each do |client|
            session, table, note = client.values_at(:session, :table, :note)
            session.get my_table_orders_path(table)
            html = Nokogiri::HTML(session.response.body)
            check(session.response.status == 200 && html.css('#my_orders > section').size == 2, 'Wrong customer order list')
            check(html.css('#my_orders > section').all? { |card| card.text.include?(note) }, 'Another customer visible')
            2.times { session.post table_service_calls_path(table) }
          end
        end
        check(@venue.service_calls.count == 30, 'Duplicate assistance calls')
      end

      scenario('Accept, serve, block unpaid cash closure') do
        parallel(@venue.orders.pluck(:id)) do |id|
          order = Order.find(id)
          order.finalize_review!
          order.serve!
        end
        check(@venue.orders.where(status: 'served', paid_at: nil).count == 180, 'Service confused with payment')
        @manager_session.post close_staff_reports_path, params: { date: Date.current.to_s }
        check(@venue.cash_closures.count.zero?, 'Cash closed with unpaid tables')
        @manager_session.follow_redirect!
        check(@manager_session.response.body.include?('mesas por pagar'), 'Unpaid closure warning missing')
      end

      scenario('Two employees charging the same order simultaneously') do
        id = @venue.orders.order(:id).first.id
        outcomes = parallel(@employees.map(&:id)) do |user_id|
          Order.find(id).mark_paid!(User.find(user_id), payment_method: 'card')
          'paid'
        rescue Order::InvalidTransition
          'blocked'
        end
        check(outcomes.sort == %w[blocked paid], 'Double payment not refused')
        check(Order.find(id).payments.active.sum(:amount) == 10, 'Double charge')
      end

      scenario('Partial payments, void and corrected payment') do
        ids = @venue.orders.order(:id).offset(1).pluck(:id)
        parallel(ids) do |id|
          order = Order.find(id)
          order.pay_item!(order.order_items.first.id, 1, User.find(@manager.id), payment_method: 'cash')
          check(order.reload.outstanding_total == 5, 'Wrong partial balance')
          order.mark_paid!(User.find(@manager.id), payment_method: 'mbway')
        end
        order = @venue.orders.order(:id).first
        payment = order.payments.active.first
        payment.void!(@manager, reason: 'Ensaio: corrigir método')
        check(order.reload.outstanding_total == 10 && !order.paid?, 'Void did not restore debt')
        order.mark_paid!(@manager, payment_method: 'cash')
        check(payment.reload.voided? && payment.amount == 10, 'Original movement lost')
      end

      scenario('Final cash reconciliation and reopening') do
        check(@venue.orders.to_a.sum(&:outstanding_total).zero?, 'Unpaid remainder')
        check(@venue.payments.active.sum(:amount) == 1800, 'Wrong received total')
        check(@venue.payments.where.not(voided_at: nil).count == 1, 'Missing void history')
        @manager_session.post close_staff_reports_path, params: { date: Date.current.to_s }
        closure = @venue.cash_closures.active.first!
        check(closure.total_amount == 1800, 'Closure does not reconcile')
        check(closure.payments_count == @venue.payments.active.count, 'Wrong payment count')
        check(closure.payment_breakdown.values.sum { |amount| BigDecimal(amount.to_s) } == 1800, 'Payment methods do not reconcile')
        closure.reopen!(@manager, reason: 'Ensaio de reabertura')
        @manager_session.post close_staff_reports_path, params: { date: Date.current.to_s }
        check(@venue.cash_closures.count == 2 && @venue.cash_closures.active.count == 1, 'Closure history lost')
      end
      @report[:status] = 'passed'
    rescue StandardError => error
      @report[:status] = 'failed'
      @report[:error] = "#{error.class}: #{error.message}"
      raise
    ensure
      @report[:scenarios] = @results
      FileUtils.mkdir_p(Rails.root.join('tmp/rehearsal'))
      File.write(Rails.root.join('tmp/rehearsal/report.json'), JSON.pretty_generate(@report))
      puts JSON.pretty_generate(@report)
    end
  end

  private

  def prepare
    @venue = Establishment.create!(name: 'Café de ensaio', slug: 'pilot-rehearsal', table_limit: 30, plan: 'management')
    category = @venue.categories.create!(name: 'Ensaio', available: true)
    @product = category.menu_items.create!(name: 'Produto de ensaio', price: 5, available: true)
    @manager = @venue.users.create!(name: 'Gerente fictício', email: 'pilot-manager@example.com', password: 'Test-password-123', role: 'manager')
    @employees = [@manager, @venue.users.create!(name: 'Funcionário fictício', email: 'pilot-staff@example.com', password: 'Test-password-123', role: 'staff')]
    @manager_session = ActionDispatch::Integration::Session.new(Rails.application)
    @manager_session.post login_path, params: { email: @manager.email, password: 'Test-password-123' }
    check(@manager_session.response.redirect?, 'Manager login failed')
    @clients = (1..30).flat_map do |number|
      table = @venue.tables.create!(number: number)
      3.times.map do |customer|
        session = ActionDispatch::Integration::Session.new(Rails.application)
        session.get new_table_order_path(table)
        check(session.response.status == 200, 'QR menu failed')
        { session: session, table: table, note: "mesa-#{number}-cliente-#{customer}" }
      end
    end
  end

  def scenario(name)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = { name: name, status: 'running' }
    @results << result
    yield
    result[:status] = 'passed'
  rescue StandardError => error
    result[:status] = 'failed'
    result[:error] = "#{error.class}: #{error.message}"
    raise
  ensure
    result[:duration_seconds] = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).round(3)
  end

  def parallel(values)
    gate = Queue.new
    ActiveRecord::Base.connection_handler.clear_active_connections!
    threads = values.map do |value|
      Thread.new do
        gate.pop
        Rails.application.executor.wrap { yield value }
      end
    end
    threads.size.times { gate << true }
    threads.map(&:value)
  ensure
    threads&.each(&:join)
  end

  def check(condition, message)
    raise message unless condition
  end
end

PilotRehearsal.new.run
