class OrdersController < ApplicationController
  before_action :set_table
  before_action :ensure_customer_token

  def new
    @categories = Category.includes(:menu_items).where(available: true).order(:name)
    @active_count = active_orders_count
  end

  def review
    note = params.dig(:order, :note).to_s.strip

    raw = params.dig(:order, :items)
    raw_hash = raw.is_a?(ActionController::Parameters) ? raw.to_unsafe_h : (raw || {})

    parsed_items = raw_hash.map do |menu_item_id, qty|
      q = qty.to_i
      next if q <= 0
      [menu_item_id.to_i, q]
    end.compact

    if parsed_items.empty?
      redirect_to new_table_order_path(@table.qr_token), alert: "Select at least one item."
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

      line_total = mi.price * qty
      @review_total += line_total

      @review_items << {
        menu_item_id: mi.id,
        name: mi.name,
        quantity: qty,
        unit_price: mi.price,
        line_total: line_total
      }
    end

    if @review_items.empty?
      redirect_to new_table_order_path(@table.qr_token), alert: "Selected items not available."
      return
    end
  end

  def create
    note = params.dig(:order, :note).to_s.strip

    raw = params.dig(:order, :items)
    raw_hash = raw.is_a?(ActionController::Parameters) ? raw.to_unsafe_h : (raw || {})

    items = raw_hash.map do |menu_item_id, qty|
      q = qty.to_i
      next if q <= 0
      [menu_item_id.to_i, q]
    end.compact

    if items.empty?
      redirect_to new_table_order_path(@table.qr_token), alert: "Select at least one item."
      return
    end

    order = @table.orders.new(note: note, customer_token: session[:customer_token], status: "pending")

    menu_index = MenuItem.includes(:category).where(id: items.map(&:first)).index_by(&:id)

    items.each do |menu_item_id, qty|
      mi = menu_index[menu_item_id]
      next unless mi
      next unless mi.available && mi.category.available

      order.order_items.build(
        menu_item: mi,
        quantity: qty,
        unit_price: mi.price,
        status: "pending"
      )
    end

    if order.order_items.empty?
      redirect_to new_table_order_path(@table.qr_token), alert: "Those items are not available."
      return
    end

    order.transaction do
      order.save!
      order.recalculate_total! if order.respond_to?(:recalculate_total!)
    end

    redirect_to my_table_orders_path(@table.qr_token), notice: "Order submitted"
  rescue ActiveRecord::RecordInvalid
    redirect_to new_table_order_path(@table.qr_token), alert: "Failed to submit order"
  end

  def my
    @orders = @table.orders
      .includes(order_items: :menu_item)
      .where(customer_token: session[:customer_token])
      .where.not(status: %w[served denied])
      .order(created_at: :desc)
  end

  # customer chooses: accept remaining items (after some denied)
  def accept_remaining
    order = find_customer_order!(params[:id])

    if order.needs_customer_action?
      order.transaction do
        # deny any still pending, keep accepted
        order.order_items.where(status: "pending").update_all(status: "denied", denial_reason: "Not available")
        order.update!(status: "accepted")
      end
    end

    redirect_to my_table_orders_path(@table.qr_token), notice: "Accepted remaining items"
  end

  def cancel
    order = find_customer_order!(params[:id])

    order.transaction do
      order.order_items.update_all(status: "denied", denial_reason: "Canceled by customer")
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
    @table.orders.where(customer_token: session[:customer_token]).find(id)
  end

  def active_orders_count
    @table.orders
      .where(customer_token: session[:customer_token])
      .where.not(status: %w[served denied])
      .count
  end
end
