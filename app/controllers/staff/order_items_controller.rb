class Staff::OrderItemsController < ApplicationController
  layout "staff"
  before_action :require_login

  def update
    @order_item = OrderItem.includes(order: [:table]).find(params[:id])

    status = params[:order_item].try(:[], :status) || params[:status]
    denial_reason = params[:order_item].try(:[], :denial_reason) || params[:denial_reason]

    unless status.in?(%w[accepted denied])
      return redirect_back fallback_location: staff_order_path(@order_item.order), alert: "Invalid status"
    end

    @order_item.update!(
      status: status,
      denial_reason: (status == "denied" ? denial_reason.to_s.strip.presence : nil)
    )

    respond_to do |format|
      format.html { redirect_to staff_order_path(@order_item.order), notice: "Item updated" }
      format.turbo_stream
    end
  end

  private

  def require_login
    redirect_to login_path unless current_user&.staff?
  end
end
