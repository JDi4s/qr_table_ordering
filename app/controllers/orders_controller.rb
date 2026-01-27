class OrdersController < ApplicationController
  before_action :set_table

  def new
    @categories = Category.includes(:menu_items).all
    @order = Order.new
  end

  def create
    @order = @table.orders.build
    params[:order][:menu_items].each do |menu_item_id, quantity|
      next if quantity.to_i <= 0
      @order.order_items.build(menu_item_id: menu_item_id, quantity: quantity)
    end

    if @order.save
      redirect_to table_order_path(@table, @order), notice: "Order submitted!"
    else
      render :new, alert: "Something went wrong."
    end
  end

  def show
    @order = @table.orders.find(params[:id])
  end

  private

  def set_table
    @table = Table.find_by!(qr_token: params[:table_id])
  end
end
