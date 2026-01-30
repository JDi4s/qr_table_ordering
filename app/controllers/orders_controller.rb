class OrdersController < ApplicationController
  before_action :set_table
  before_action :ensure_customer_token

  def new
    @order = @table.orders.new
    @categories = Category.available.includes(:menu_items)
                          .map { |c| [c, c.menu_items.available] }
  end

  def create
    raw_items = params.dig(:order, :order_items_attributes) || {}
    note = params.dig(:order, :note).to_s.strip

    items = raw_items.values.map do |h|
      menu_item_id = h[:menu_item_id].presence
      qty = h[:quantity].to_i
      next if menu_item_id.blank? || qty <= 0
      { menu_item_id: menu_item_id.to_i, quantity: qty }
    end.compact

    if items.empty?
      @order = @table.orders.new(note: note)
      @categories = Category.available.includes(:menu_items)
                            .map { |c| [c, c.menu_items.available] }
      flash.now[:alert] = "Select at least one item"
      render :new, status: :unprocessable_entity
      return
    end

    @order = @table.orders.new(note: note, customer_token: session[:customer_token])

    menu_index = MenuItem.includes(:category).where(id: items.map { _1[:menu_item_id] }).index_by(&:id)

    items.each do |item|
      mi = menu_index[item[:menu_item_id]]
      next unless mi
      next unless mi.available && mi.category.available

      @order.order_items.build(
        menu_item: mi,
        quantity: item[:quantity],
        unit_price: mi.price,
        status: "pending"
      )
    end

    if @order.order_items.empty?
      @categories = Category.available.includes(:menu_items)
                            .map { |c| [c, c.menu_items.available] }
      flash.now[:alert] = "Those items are not available right now"
      render :new, status: :unprocessable_entity
      return
    end

    if @order.save
      redirect_to my_table_orders_path(@table.qr_token), notice: "Order submitted"
    else
      @categories = Category.available.includes(:menu_items)
                            .map { |c| [c, c.menu_items.available] }
      render :new, status: :unprocessable_entity
    end
  end

  def my
    # ONLY show orders created by this customer session for this table
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
