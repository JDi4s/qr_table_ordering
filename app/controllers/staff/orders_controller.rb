class Staff::OrdersController < Staff::BaseController
  def index
    @activation_tables = current_establishment.tables.where(active: true, deleted_at: nil).includes(:current_table_visit).order(:number).to_a
    scope = current_establishment.orders.not_voided.includes(:table, order_items: { menu_item: :production_area }).where.not(status: %w[served denied])
    if current_user.staff? && current_establishment.production_areas_enabled? && current_user.production_area_ids.any?
      scope = scope.where(<<~SQL, areas: current_user.production_area_ids)
        EXISTS (
          SELECT 1 FROM order_items oi
          WHERE oi.order_id = orders.id AND (
            oi.menu_item_id IN (SELECT id FROM menu_items WHERE production_area_id IN (:areas)) OR
            EXISTS (
              SELECT 1 FROM jsonb_array_elements(COALESCE(oi.lunch_selection->'choices', '[]'::jsonb)) choice
              JOIN menu_items mi ON mi.id::text = choice->>'menu_item_id'
              WHERE mi.production_area_id IN (:areas)
            )
          )
        )
      SQL
    end
    @orders = scope.order(:created_at).to_a
    @area_filter_active = current_user.staff? && current_establishment.production_areas_enabled? && current_user.production_area_ids.any?
    @service_calls = current_establishment.service_calls.includes(:table, :assigned_user).where.not(status: 'resolved').order(:created_at).to_a
  end

  def mark_paid
    order = current_establishment.orders.find(params[:id])
    order.mark_paid!(current_user, payment_method: payment_method_param)
    AuditLogger.record(user: current_user, action: 'payment_received', record: order, metadata: { amount: order.payments.order(:created_at).last.amount.to_s, payment_method: payment_method_param })
    redirect_back fallback_location: active_staff_tables_path, notice: "Pedido ##{order.id} marcado como pago.", status: :see_other
  end

  def pay_item
    order = current_establishment.orders.find(params[:id])
    order.pay_item!(params[:order_item_id], params[:quantity], current_user, payment_method: payment_method_param)
    payment = order.payments.order(:created_at).last
    AuditLogger.record(user: current_user, action: 'payment_received', record: order, metadata: { amount: payment.amount.to_s, payment_method: payment.payment_method })
    redirect_back fallback_location: staff_table_path(order.table), notice: 'Artigo marcado como pago.', status: :see_other
  end

  def pay_selected
    order = current_establishment.orders.find(params[:id])
    if params[:pay_all] == '1'
      order.mark_paid!(current_user, payment_method: payment_method_param)
    else
      order.pay_selected_items!(selected_items_params, current_user, payment_method: payment_method_param)
    end
    payment = order.payments.order(:created_at).last
    AuditLogger.record(user: current_user, action: 'payment_received', record: order,
                       metadata: { amount: payment.amount.to_s, payment_method: payment.payment_method })
    if order.fully_paid?
      next_order = order.table.orders.unpaid.order(:created_at, :id).first
      destination = if next_order
                      staff_table_path(order.table, open_order: next_order.id, anchor: "order-#{next_order.id}")
                    else
                      active_staff_tables_path
                    end
      redirect_to destination, notice: 'Artigos selecionados marcados como pagos.', status: :see_other
    else
      redirect_to staff_table_path(order.table, open_order: order.id, anchor: "order-#{order.id}"),
                  notice: 'Artigos selecionados marcados como pagos.', status: :see_other
    end
  end

  def show
    @order = current_establishment.orders.includes(:table, order_items: :menu_item, payments: :user).find(params[:id])
  end

  def update
    order = current_establishment.orders.find(params[:id])
    case params[:status]
    when 'accepted'
      order.finalize_review!
      AuditLogger.record(user: current_user, action: 'order_accepted', record: order)
    when 'denied'
      order.reject!(params[:denial_reason])
      AuditLogger.record(user: current_user, action: 'order_cancelled', record: order,
                         metadata: { actor: 'staff', reason: params[:denial_reason] })
    when 'served'
      order.serve!
      AuditLogger.record(user: current_user, action: 'order_served', record: order)
    else raise Order::InvalidTransition, 'Estado inválido.'
    end
    respond_to do |format|
      format.turbo_stream { head :no_content }
      format.html { redirect_to staff_order_path(order), notice: 'Pedido atualizado.', status: :see_other }
    end
  end

  def history
    @history_status = %w[served denied].include?(params[:status].to_s) ? params[:status].to_s : 'all'
    requested_period = params[:from].present? || params[:to].present? ? 'custom' : params[:period].to_s
    @history_period = %w[today yesterday last_7_days custom all].include?(requested_period) ? requested_period : 'today'

    now = Time.zone.now
    case @history_period
    when 'today'
      @history_from = now.beginning_of_day
      @history_to = now.end_of_day
    when 'yesterday'
      @history_from = 1.day.ago.beginning_of_day
      @history_to = 1.day.ago.end_of_day
    when 'last_7_days'
      @history_from = 6.days.ago.beginning_of_day
      @history_to = now.end_of_day
    when 'custom'
      @history_from = parse_history_time(params[:from])
      @history_to = parse_history_time(params[:to])
    else
      @history_from = nil
      @history_to = nil
    end

    scope = current_establishment.orders
      .includes(:table, :payments, order_items: :menu_item)
      .where('orders.status IN (?) OR orders.voided_at IS NOT NULL', %w[served denied])

    if @history_status == 'served'
      scope = scope.where(status: 'served', voided_at: nil)
    elsif @history_status == 'denied'
      scope = scope.where("orders.status = 'denied' OR orders.voided_at IS NOT NULL")
    end
    if @history_from && @history_to
      from_time, to_time = [@history_from, @history_to].minmax
      scope = scope.where(created_at: from_time..to_time)
    elsif @history_from
      scope = scope.where('created_at >= ?', @history_from)
    elsif @history_to
      scope = scope.where('created_at <= ?', @history_to)
    end

    @history_from_value = @history_from&.strftime('%Y-%m-%dT%H:%M')
    @history_to_value = @history_to&.strftime('%Y-%m-%dT%H:%M')
    @history_query = params[:q].to_s.strip.first(40)

    if @history_query.present?
      match = @history_query.match(/\A(?:(mesa|pedido)\s*#?\s*|#)?(\d+)\z/i)
      if match
        number = match[2].to_i
        scope = scope.joins(:table)
        scope = case match[1]&.downcase
                when 'mesa' then scope.where(tables: { number: number })
                when 'pedido' then scope.where(id: number)
                else scope.where('orders.id = :number OR tables.number = :number', number: number)
                end
      else
        scope = scope.none
      end
    end

    @history_total = scope.count
    @history_tables = scope.distinct.count(:table_id)
    @history_page_count = [(@history_total.to_f / 20).ceil, 1].max
    @history_page = [[params[:page].to_i, 1].max, @history_page_count].min
    @orders = scope.order(created_at: :desc, id: :desc).limit(20).offset((@history_page - 1) * 20).to_a

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  private

  def selected_items_params
    params.permit(:payment_method, items: {}).fetch(:items, {}).to_h
  end

  def parse_history_time(value)
    return if value.blank?

    Time.zone.strptime(value.to_s, '%Y-%m-%dT%H:%M')
  rescue ArgumentError
    nil
  end

  def payment_method_param
    value = params[:payment_method].to_s
    Payment.payment_methods.key?(value) ? value : 'cash'
  end
end
