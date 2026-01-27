class OrdersController < ApplicationController
  before_action :set_table

  def new
    @menu_items = MenuItem.all
    @order = @table.orders.new
  end

  def create
    @order = @table.orders.new(order_params)
    if @order.save
      redirect_to table_order_path(@table, @order), notice: "Order submitted!"
    else
      render :new
    end
  end

  def show
    @order = @table.orders.find(params[:id])
  end

  private

  def set_table
    @table = Table.find_by!(qr_token: params[:table_id])
  end

  def order_params
    params.require(:order).permit(order_items_attributes: [:menu_item_id, :quantity])
  end
end
