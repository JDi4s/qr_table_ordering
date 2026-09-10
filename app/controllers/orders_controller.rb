class OrdersController < ApplicationController
  before_action :set_table
  before_action :ensure_customer_token

  def new
    @categories = @table.establishment.categories.not_archived.includes(:menu_items, :children).where(available: true).order(:name)
    @active_count = customer_orders.where.not(status: %w[served denied]).count
    @cart_quantities = draft_quantities
    @cart_note = draft_note
  end

  def review
    if request.get?
      redirect_to new_table_order_path(@table), status: :see_other
      return
    end

    @review_note = params.dig(:order, :note).to_s.strip
    @review_items = selected_items
    save_draft(@review_items, @review_note)
    @review_suggestions = suggestions_for(@review_items)
    @review_total = @review_items.sum { |item| item[:line_total] }
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

    note = params.dig(:order, :note)
    note = quote[:note] if note.nil?
    note = note.to_s.strip
    raise Order::InvalidTransition, 'As observações não podem ultrapassar 1000 caracteres.' if note.length > 1000

    @table.with_lock do
      raise Order::InvalidTransition, 'Esta mesa está desativada.' unless @table.active? && @table.establishment.reload.active?

      unless customer_orders.exists?(submission_token: quote[:nonce])
        order = @table.orders.new(note: note, customer_token: session[:customer_token], submission_token: quote[:nonce], status: 'pending')

        items = quote[:items].dup
        suggestion_items = valid_suggestion_items(quote[:items].map(&:first), params[:suggestion_quantities], params[:suggestion_ids])
        suggestion_items.each { |id, quantity| items << [id, quantity, nil] }

        items.each do |id, qty, price|
          item = @table.establishment.menu_items.includes(:category).find(id)

          unless item.available? && !item.archived? && item.category.visible_to_customers? && (price.blank? || item.price == BigDecimal(price))
            raise Order::InvalidTransition, 'O menu mudou. Reveja os produtos e preços antes de enviar.'
          end

          order.order_items.build(menu_item: item, quantity: qty, unit_price: item.price, status: 'pending')
        end

        order.total = order.order_items.sum { |item| item.unit_price * item.quantity }
        order.save!
      end
    end

    session.delete(:order_draft)
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
    order = customer_orders.find(params[:id])
    order.reject!(nil, customer: true)
    AuditLogger.record(user: nil, action: 'order_cancelled', record: order, metadata: { actor: 'customer', reason: order.cancellation_reason })
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

  def save_draft(items, note)
    session[:order_draft] = {
      'items' => items.to_h { |item| [item[:menu_item_id].to_s, item[:quantity].to_i] },
      'note' => note
    }
  end

  def draft_quantities
    raw_items = session.dig(:order_draft, 'items') || session.dig(:order_draft, :items) || {}
    raw_items.to_h.each_with_object({}) do |(id, quantity), result|
      next unless id.to_s.match?(/\A\d+\z/)

      parsed_quantity = Integer(quantity, exception: false)
      result[id.to_s] = parsed_quantity if parsed_quantity && parsed_quantity.positive?
    end
  end

  def draft_note
    session.dig(:order_draft, 'note') || session.dig(:order_draft, :note).to_s
  end

  def selected_items
    raw = params.dig(:order, :items)
    raise Order::InvalidTransition, 'Selecione pelo menos um produto.' unless raw.is_a?(ActionController::Parameters)
    raise Order::InvalidTransition, 'Demasiados produtos num pedido.' if raw.keys.size > 200

    items = raw.to_unsafe_h.filter_map do |id, qty|
      raise Order::InvalidTransition, 'Quantidade inválida.' unless qty.to_s.match?(/\A\d{1,2}\z/)
      next if qty.to_i.zero?

      item = @table.establishment.menu_items.includes(:category).find(id)
      raise Order::InvalidTransition, "#{item.name} já não está disponível." unless item.available? && !item.archived? && item.category.visible_to_customers?

      { menu_item_id: item.id, name: item.name, quantity: qty.to_i, unit_price: item.price, line_total: item.price * qty.to_i }
    end

    raise Order::InvalidTransition, 'Selecione pelo menos um produto.' if items.empty?
    items
  end

  def suggestions_for(items)
    ids = items.map { |item| item[:menu_item_id] }
    return MenuItem.none if ids.empty?

    scope = @table.establishment.menu_items.not_archived
      .joins(:recommended_by, :category)
      .where(menu_item_recommendations: { menu_item_id: ids })
      .where.not(id: ids)
      .where(available: true)
      .where(categories: { archived_at: nil })
      .distinct
    return scope.order(:name).limit(4) if scope.exists?

    source_items = @table.establishment.menu_items.includes(category: :parent).where(id: ids).to_a
    MenuSuggestionEngine.call(
      source_items: source_items,
      scope: @table.establishment.menu_items.not_archived.where(available: true),
      limit: 4
    )
  end

  def valid_suggestion_items(source_ids, raw_quantities, raw_ids = nil)
    quantities = if raw_quantities.respond_to?(:to_unsafe_h)
      raw_quantities.to_unsafe_h.filter_map do |id, quantity|
        next if quantity.to_s == '0'
        next unless quantity.to_s.match?(/\A[1-9]\d?\z/)

        parsed_id = Integer(id, exception: false)
        parsed_id ? [parsed_id, quantity.to_i] : nil
      end
    else
      Array(raw_ids).filter_map do |id|
        parsed_id = Integer(id, exception: false)
        parsed_id ? [parsed_id, 1] : nil
      end
    end
    ids = quantities.map(&:first).uniq
    return [] if ids.empty?

    allowed = MenuItemRecommendation
      .where(menu_item_id: source_ids, recommended_menu_item_id: ids)
      .where.not(recommended_menu_item_id: source_ids)
      .pluck(:recommended_menu_item_id)

    source_items = @table.establishment.menu_items.includes(category: :parent).where(id: source_ids).to_a
    automatic = MenuSuggestionEngine.call(
      source_items: source_items,
      scope: @table.establishment.menu_items.not_archived.where(available: true),
      limit: 4
    ).map(&:id)
    allowed = (allowed + automatic).uniq

    allowed = @table.establishment.menu_items.not_archived
      .where(id: allowed, available: true)
      .select { |item| item.category.visible_to_customers? }
      .map(&:id)

    allowed = allowed & ids
    quantities.filter_map { |id, quantity| [id, quantity] if allowed.include?(id) }
  end
end
