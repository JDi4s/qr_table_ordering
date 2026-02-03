class OrdersController < ApplicationController
  before_action :set_table
  before_action :ensure_customer_token

  def new
    @order = @table.orders.new
    @categories = Category.includes(:menu_items).order(:name)
    @active_count = active_orders_count
  end

  # POST /tables/:table_id/orders/review
  # Recebe items + note, mostra um resumo antes de submeter o pedido final
  def review
    note = params.dig(:order, :note).to_s.strip

    raw = params.dig(:order, :items)
    raw_hash =
      if raw.is_a?(ActionController::Parameters)
        raw.to_unsafe_h
      else
        raw || {}
      end

    parsed_items = raw_hash.map do |menu_item_id, qty|
      q = qty.to_i
      next if q <= 0
      [menu_item_id.to_i, q]
    end.compact

    if parsed_items.empty?
      redirect_to new_table_order_path(@table.qr_token), alert: "Select at least one item to review."
      return
    end

    menu_items = MenuItem.includes(:category).where(id: parsed_items.map(&:first)).index_by(&:id)

    @review_note  = note
    @review_items = []
    @review_total = 0

    parsed_items.each do |menu_item_id, qty|
      mi = menu_items[menu_item_id]
      next unless mi
      next unless mi.available && mi.category.available

      unit_price = mi.price
      line_total = unit_price * qty
      @review_total += line_total

      @review_items << {
        menu_item_id: mi.id,
        name: mi.name,
        quantity: qty,
        unit_price: unit_price,
        line_total: line_total
      }
    end

    if @review_items.empty?
      redirect_to new_table_order_path(@table.qr_token), alert: "Selected items are not available right now."
      return
    end
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
      redirect_to new_table_order_path(@table.qr_token), alert: "Select at least one item."
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
      redirect_to new_table_order_path(@table.qr_token), alert: "Those items are not available right now."
      return
    end

    if @order.save
      redirect_to my_table_orders_path(@table.qr_token), notice: "Order submitted"
    else
      redirect_to new_table_order_path(@table.qr_token), alert: "Failed to submit order"
    end
  end

  def my
    @orders = @table.orders
                   .includes(order_items: :menu_item)
                   .where(customer_token: session[:customer_token])
                   .where.not(status: %w[served denied])
                   .order(created_at: :desc)
  end

  def accept_remaining
    order = find_customer_order!(params[:id])

    unless order.needs_customer_action?
      redirect_to my_table_orders_path(@table.qr_token), alert: "No action needed for this order"
      return
    end

    if order.order_items.any?(&:pending?)
      order.update!(status: "pending")
    else
      order.update!(status: "accepted")
    end

    redirect_to my_table_orders_path(@table.qr_token), notice: "Accepted remaining items"
  end

  def cancel
    order = find_customer_order!(params[:id])

    order.transaction do
      order.order_items.where(status: "pending").update_all(status: "denied", denial_reason: "Canceled by customer")
      order.update!(status: "denied", denial_reason: "Canceled by customer")
    end

    redirect_to my_table_orders_path(@table.qr_token), notice: "Order canceled"
  end

  private

  def set_table
    @table = Table.find_by!(qr_token: params[:table_id])
  end

  def ensure_customer_token
    session[:customer_token] ||= SecureRandom.hex(16)
  end

  def find_customer_order!(id)
    @table.orders.includes(order_items: :menu_item)
          .where(customer_token: session[:customer_token])
          .find(id)
  end

  def active_orders_count
    @table.orders
          .where(customer_token: session[:customer_token])
          .where(served_at: nil)
          .where.not(status: "denied")
          .count
  end
end
