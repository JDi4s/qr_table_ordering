class OrdersController < ApplicationController
  before_action :set_table
  before_action :ensure_customer_token

  def new
    @categories = @table.establishment.categories.includes(:menu_items).where(available: true).order(:name)
    @active_count = customer_orders.where.not(status: %w[served denied]).count
  end

  def review
    @review_note = params.dig(:order, :note).to_s.strip
    @review_items = selected_items
    @review_total = @review_items.sum { |item| item[:line_total] }
    # The signed quote makes double submissions idempotent and detects price changes.
    @quote = Rails.application.message_verifier(:order_quote).generate(
      { table_id: @table.id, customer_token: session[:customer_token], nonce: SecureRandom.hex(16),
        items: @review_items.map { |i| [i[:menu_item_id], i[:quantity], i[:unit_price].to_s] }, note: @review_note },
      expires_in: 15.minutes
    )
  end

  def create
    quote = Rails.application.message_verifier(:order_quote).verified(params[:quote].to_s)&.deep_symbolize_keys
    unless quote && quote[:table_id] == @table.id && quote[:customer_token] == session[:customer_token]
      raise Order::InvalidTransition, 'A revisão expirou. Reveja o pedido novamente.'
    end
    @table.with_lock do
      raise Order::InvalidTransition, 'Esta mesa está desativada.' unless @table.active? && @table.establishment.reload.active?
      unless customer_orders.exists?(submission_token: quote[:nonce])
        order = @table.orders.new(note: quote[:note], customer_token: session[:customer_token], submission_token: quote[:nonce], status: 'pending')
        quote[:items].each do |id, qty, price|
          item = @table.establishment.menu_items.includes(:category).find(id)
          unless item.available? && item.category.available? && item.price == BigDecimal(price)
            raise Order::InvalidTransition, 'O menu mudou. Reveja os produtos e preços antes de enviar.'
          end
          order.order_items.build(menu_item: item, quantity: qty, unit_price: item.price, status: 'pending')
        end
        order.total = order.order_items.sum { |item| item.unit_price * item.quantity }
        order.save!
      end
    end
    redirect_to my_table_orders_path(@table), notice: 'Pedido enviado.', status: :see_other
  end

  def my
    @orders = customer_orders.includes(order_items: :menu_item).order(created_at: :desc).limit(30)
  end

  def accept_remaining
    customer_orders.find(params[:id]).accept_remaining!
    redirect_to my_table_orders_path(@table), notice: 'Alterações aceites.', status: :see_other
  end

  def cancel
    customer_orders.find(params[:id]).reject!(nil, customer: true)
    redirect_to my_table_orders_path(@table), notice: 'Pedido cancelado.', status: :see_other
  end

  private

  def set_table
    @table = Table.joins(:establishment).where(active: true, establishments: { active: true }).find_by!(qr_token: params[:table_id])
  end

  def ensure_customer_token
    session[:customer_token] ||= SecureRandom.hex(24)
  end

  def customer_orders
    @table.orders.where(customer_token: session[:customer_token])
  end

  def selected_items
    raw = params.dig(:order, :items)
    raise Order::InvalidTransition, 'Selecione pelo menos um produto.' unless raw.is_a?(ActionController::Parameters)
    raise Order::InvalidTransition, 'Demasiados produtos num pedido.' if raw.keys.size > 200
    items = raw.to_unsafe_h.filter_map do |id, qty|
      raise Order::InvalidTransition, 'Quantidade inválida.' unless qty.to_s.match?(/\A\d{1,2}\z/)
      next if qty.to_i.zero?
      item = @table.establishment.menu_items.includes(:category).find(id)
      raise Order::InvalidTransition, "#{item.name} já não está disponível." unless item.available? && item.category.available?
      { menu_item_id: item.id, name: item.name, quantity: qty.to_i, unit_price: item.price, line_total: item.price * qty.to_i }
    end
    raise Order::InvalidTransition, 'Selecione pelo menos um produto.' if items.empty?
    items
  end
end
