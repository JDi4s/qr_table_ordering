class Staff::OrdersController < ApplicationController
  layout "staff"
  before_action :require_login

  # LIVE = tudo o que ainda não foi concluído
  # (fica aqui mesmo que esteja accepted)
  def index
    @orders = Order
      .includes(:table, order_items: :menu_item)
      .where.not(status: %w[served denied])
      .order(created_at: :asc)
  end

  def show
    @order = Order.includes(:table, order_items: :menu_item).find(params[:id])
  end

  def update
    @order = Order.includes(order_items: :menu_item).find(params[:id])

    case params[:status]
    when "accepted"
      accept_order!
      notice = "Order accepted"
    when "denied"
      deny_order!
      notice = "Order denied"
    when "served"
      serve_order!
      notice = "Order served"
    else
      return redirect_to staff_orders_path, alert: "Invalid status"
    end

    respond_to do |format|
      format.html { redirect_to staff_orders_path, notice: notice }
      format.turbo_stream
    end
  end

  def history
    @orders = Order
      .includes(:table, order_items: :menu_item)
      .where(status: %w[served denied])
      .order(created_at: :desc)
  end

  def clear_history
    Order.where(status: %w[served denied]).destroy_all
    redirect_to history_staff_orders_path, notice: "History cleared"
  end

  private

  def accept_order!
    @order.transaction do
      @order.order_items.each do |oi|
        next unless oi.pending?
        oi.update!(status: "accepted", denial_reason: nil)
      end

      @order.sync_status_from_items! if @order.respond_to?(:sync_status_from_items!)
      @order.update!(status: "accepted") if @order.pending?
    end
  end

  def deny_order!
    reason = params[:denial_reason].presence

    @order.transaction do
      @order.order_items.each do |oi|
        if oi.pending?
          oi.update!(status: "denied", denial_reason: reason || "Denied by staff")
        end
      end

      @order.update!(status: "denied", denial_reason: reason || "Denied by staff")
    end
  end

  def serve_order!
    @order.update!(status: "served", served_at: Time.current)
  end

  def require_login
    redirect_to login_path unless current_user&.staff?
  end
end
