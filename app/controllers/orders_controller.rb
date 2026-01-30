class OrdersController < ApplicationController
  before_action :set_table
  before_action :ensure_customer_token

  def new
    @order = @table.orders.new
    @categories = Category.includes(:menu_items).order(:name)
  end

  def create
    note = params.dig(:order, :note).to_s.strip

    raw = params.dig(:order, :items)
    raw_hash =
      if raw.is_a?(ActionController::Parameters)
        raw.to_unsafe_h
      else
        raw || {}
      end

    items = raw_hash.map do |menu_item_id, qty|
      q = qty.to_i
      next if q <= 0
      [menu_item_id.to_i, q]
    end.compact

    if items.empty?
      @order = @table.orders.new(note: note)
      @categories = Category.includes(:menu_items).order(:name)
      flash.now[:alert] = "Select at least one item"
      render :new, status: :unprocessable_entity
      return
    end

    @order = @table.orders.new(note: note, customer_token: session[:customer_token])

    menu_index = MenuItem.includes(:category).where(id: items.map(&:first)).index_by(&:id)

    items.each do |menu_item_id, qty|
      mi = menu_index[menu_item_id]
      next unless mi
      next unless mi.available && mi.category.available

      @order.order_items.build(
        menu_item: mi,
        quantity: qty,
        unit_price: mi.price,
        status: "pending"
      )
    end

    if @order.order_items.empty?
      @categories = Category.includes(:menu_items).order(:name)
      flash.now[:alert] = "Those items are not available right now"
      render :new, status: :unprocessable_entity
      return
    end

    if @order.save
      redirect_to my_table_orders_path(@table.qr_token), notice: "Order submitted"
    else
      @categories = Category.includes(:menu_items).order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def my
    @orders = @table.orders
                   .includes(order_items: :menu_item)
                   .where(customer_token: session[:customer_token])
                   .where.not(status: %w[served denied])
                   .order(created_at: :desc)
  end

  private

  def set_table
    @table = Table.find_by!(qr_token: params[:table_id])
  end

  def ensure_customer_token
    session[:customer_token] ||= SecureRandom.hex(16)
  end
end
