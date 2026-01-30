class Staff::OrderItemsController < ApplicationController
  layout "staff"
  before_action :require_login

  def update
    @order_item = OrderItem.includes(:menu_item, :order).find(params[:id])

    unless params[:status].in?(%w[accepted denied pending])
      return redirect_back fallback_location: staff_orders_path, alert: "Invalid status"
    end

    attrs = { status: params[:status] }

    if params[:status] == "denied"
      attrs[:denial_reason] = params[:denial_reason].presence
    else
      attrs[:denial_reason] = nil
    end

    @order_item.update!(attrs)

    respond_to do |format|
      format.html { redirect_back fallback_location: staff_order_path(@order_item.order), notice: "Item updated" }
      format.turbo_stream
    end
  end

  private

  def require_login
    redirect_to login_path unless current_user&.staff?
  end
end
