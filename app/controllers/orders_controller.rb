class OrdersController < ApplicationController
  before_action :set_table

  def new
    @order = @table.orders.new
    @categories = Category.includes(:menu_items).all
  end

  def create
    @order = @table.orders.new(order_params)
    if @order.save
      redirect_to table_order_path(@table.qr_token, @order), notice: "Order submitted successfully"
    else
      @categories = Category.includes(:menu_items).all
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @order = Order.includes(order_items: :menu_item).find(params[:id])
  end

  private

  def set_table
    @table = Table.find_by!(qr_token: params[:table_id])
  end

  def order_params
    params.require(:order).permit(order_items_attributes: [:menu_item_id, :quantity])
  end
end
