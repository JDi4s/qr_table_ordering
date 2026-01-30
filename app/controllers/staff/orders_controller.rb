class Staff::OrdersController < ApplicationController
  layout "staff"
  before_action :require_login

  def index
    @orders = Order.includes(:table, order_items: :menu_item)
                  .where(status: "pending")
                  .order(created_at: :desc)
  end

  def show
    @order = Order.includes(order_items: :menu_item).find(params[:id])
  end

  def update
    @order = Order.find(params[:id])

    unless params[:status].in?(%w[accepted denied served pending])
      return redirect_to staff_orders_path, alert: "Invalid status"
    end

    if params[:status] == "served"
      @order.update!(status: "served", served_at: Time.current)
    elsif params[:status] == "denied"
      @order.update!(status: "denied", denial_reason: params[:denial_reason].presence)
    else
      @order.update!(status: params[:status], denial_reason: nil)
    end

    respond_to do |format|
      format.html { redirect_to staff_orders_path, notice: "Order updated" }
      format.turbo_stream
    end
  end

  def history
    @orders = Order.includes(:table, order_items: :menu_item)
                  .where(status: %w[served denied])
                  .order(created_at: :desc)
  end

  def clear_history
    Order.where(status: %w[served denied]).find_each(&:destroy)
    redirect_to history_staff_orders_path, notice: "History cleared"
  end

  private

  def require_login
    redirect_to login_path unless current_user&.staff?
  end
end
