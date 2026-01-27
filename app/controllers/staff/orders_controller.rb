class Staff::OrdersController < ApplicationController
  before_action :require_login

  def index
    @orders = Order.includes(order_items: :menu_item, table: {}).order(created_at: :desc)
  end

  def show
    @order = Order.includes(order_items: :menu_item).find(params[:id])
  end

  def update
    @order = Order.find(params[:id])
    if params[:status].in?(%w[accepted denied])
      @order.update(status: params[:status])
      redirect_to staff_orders_path, notice: "Order updated"
    else
      redirect_to staff_orders_path, alert: "Invalid status"
    end
  end

  private

  def require_login
    unless current_user&.staff?
      redirect_to login_path, alert: "Please log in as staff"
    end
  end

  def current_user
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  end
end
