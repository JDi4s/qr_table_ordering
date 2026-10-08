class OrdersController < ApplicationController
  before_action :set_table
  before_action :ensure_customer_token, except: [:access_status, :menu_snapshot]
  before_action :ensure_service_accepting_orders, only: [:review, :create]
  before_action :load_table_visit
  before_action :ensure_visit_open, only: :create

  def new
    @table_visit = TableVisit.request_for!(@table)
    visits = session[:table_visit_ids] ||= {}
    visits.delete(@table.id.to_s)
    visits[@table.id.to_s] = @table_visit.id
    session[:table_visit_ids] = visits.to_a.last(12).to_h
    @categories = @table.establishment.categories.not_archived.includes(:menu_items, :children).where(available: true).order(:name)
    @active_count = customer_orders.where.not(status: %w[served denied]).count
    @cart_quantities = draft_quantities
    @cart_note = draft_note
    @lunch_draft = session.dig(:order_draft, "lunch") || {}
  end

  def review
    if request.get?
      redirect_to new_table_order_path(@table), status: :see_other
      return
    end

    unless @table_visit && @table_visit.closed_at.nil?
      redirect_to new_table_order_path(@table), alert: 'Esta visita terminou. Abre o menu para iniciar uma nova visita.', status: :see_other
      return
    end

    @review_note = params.dig(:order, :note).to_s.strip
    @review_items = selected_items
    save_draft(@review_items, @review_note)
    @review_suggestions = suggestions_for(@review_items)
    @review_total = @review_items.sum { |item| item[:line_total] }
    @quote = Rails.application.message_verifier(:order_quote).generate(
      { table_id: @table.id, table_visit_id: @table_visit.id, customer_token: session[:customer_token], nonce: SecureRandom.hex(16),
        items: @review_items.map { |i| [i[:menu_item_id], i[:quantity], i[:unit_price].to_s] + (i[:lunch_selection] ? [i[:lunch_selection]] : []) }, note: @review_note },
      expires_in: 15.minutes
    )
  end

  def create
    quote = Rails.application.message_verifier(:order_quote).verified(params[:quote].to_s)&.deep_symbolize_keys
    unless quote && quote[:table_id] == @table.id && quote[:table_visit_id] == @table_visit.id && quote[:customer_token] == session[:customer_token]
      raise Order::InvalidTransition, 'A revisão expirou. Reveja o pedido novamente.'
    end

    note = params.dig(:order, :note)
    note = quote[:note] if note.nil?
    note = note.to_s.strip
    raise Order::InvalidTransition, 'As observações não podem ultrapassar 1000 caracteres.' if note.length > 1000

    @table.establishment.with_lock do
      @table.with_lock do
        establishment = @table.establishment.reload
        raise Order::InvalidTransition, 'Esta mesa está desativada.' unless @table.active? && establishment.active?
        raise Order::InvalidTransition, 'O serviço está temporariamente pausado. Ainda não é possível enviar pedidos.' unless establishment.accepting_orders?
        visit = @table.table_visits.find(@table_visit.id)
        raise Order::InvalidTransition, 'Esta visita terminou ou ainda não foi ativada pela equipa.' unless visit.open?

        unless customer_orders.exists?(submission_token: quote[:nonce])
          order = @table.orders.new(table_visit: visit, note: note, customer_token: session[:customer_token], submission_token: quote[:nonce], status: 'pending')

          items = quote[:items].dup
          suggestion_items = valid_suggestion_items(quote[:items].map(&:first), params[:suggestion_quantities], params[:suggestion_ids])
          suggestion_items.each { |id, quantity| items << [id, quantity, nil] }

          items.each do |id, qty, price, lunch|
            if lunch.present?
              row = LunchMenu.validated_selection(establishment, lunch, id, qty, price)
              order.order_items.build(menu_item_id: row[:menu_item_id], name_snapshot: row[:name], quantity: row[:quantity],
                unit_price: row[:unit_price], lunch_selection: row[:lunch_selection], status: 'pending')
              next
            end
            item = establishment.menu_items.includes(:category).find(id)

            unless item.available? && !item.archived? && item.category.visible_to_customers? && (price.blank? || item.price == BigDecimal(price))
              raise Order::InvalidTransition, 'O menu mudou. Reveja os produtos e preços antes de enviar.'
            end

            order.order_items.build(menu_item: item, quantity: qty, unit_price: item.price, status: 'pending')
          end

          order.total = order.order_items.sum { |item| item.unit_price * item.quantity }
          order.save!
        end
      end
    end

    session.delete(:order_draft)
    redirect_to my_table_orders_path(@table), notice: 'Pedido enviado.', status: :see_other
  end

  def my
    history = CustomerVisitHistory.new(customer_orders.includes(:table_visit, order_items: :menu_item).to_a)
    @current_visit = history.current_visit
    @previous_visits = history.previous_visits
    @orders = @current_visit ? @current_visit.orders.reverse : []
  end

  def menu_snapshot
    request.session_options[:skip] = true
    render body: CustomerMenuBroadcast.message(@table.establishment), content_type: 'text/vnd.turbo-stream.html'
  end

  def access_status
    # A read-only poll must not overwrite a newer visit cookie after navigation.
    request.session_options[:skip] = true
    response.headers['Cache-Control'] = 'no-store, private'
    render json: { visit_id: @table_visit&.id, state: @table_visit&.state || 'closed',
                   allowed: !!(@table_visit&.open? && @table.establishment.accepting_orders?) }
  end

  def cancel
    order = customer_orders.find(params[:id])
    order.reject!(nil, customer: true)
    AuditLogger.record(user: nil, action: 'order_cancelled', record: order, metadata: { actor: 'customer', reason: order.cancellation_reason })
    redirect_to my_table_orders_path(@table), notice: 'Pedido cancelado.', status: :see_other
  end

  private

  def set_table
    response.headers['Cache-Control'] = 'no-store, private'
    @table = Table.joins(:establishment).where(active: true, deleted_at: nil, establishments: { active: true }).find_by!(qr_token: params[:table_id])
  end

  def ensure_customer_token
    session[:customer_token] ||= SecureRandom.hex(24)
  end

  def load_table_visit
    id = session.dig(:table_visit_ids, @table.id.to_s)
    @table_visit = @table.table_visits.find_by(id: id)
  end

  def ensure_visit_open
    return if @table_visit&.open?
    redirect_to new_table_order_path(@table),
                alert: 'A tua mesa ainda não está ativa. Aguarda que a equipa a ative para enviares o pedido.', status: :see_other
  end

  def ensure_service_accepting_orders
    return if @table.establishment.accepting_orders?

    redirect_to new_table_order_path(@table),
                alert: 'O serviço está temporariamente pausado. Podes consultar o menu, mas ainda não é possível enviar pedidos.',
                status: :see_other
  end

  def customer_orders
    @table.orders.not_voided.where(customer_token: session[:customer_token])
  end

  def save_draft(items, note)
    session[:order_draft] = {
       'items' => items.reject { |item| item[:lunch_selection] }.to_h { |item| [item[:menu_item_id].to_s, item[:quantity].to_i] },
      'lunch' => {
        'individual' => items.select { |item| item.dig(:lunch_selection, 'kind') == 'individual' }.to_h { |item| [item[:menu_item_id].to_s, item[:quantity]] },
        'combos' => items.select { |item| item.dig(:lunch_selection, 'kind') == 'combo' }.map { |item| { 'quantity' => item[:quantity], 'choices' => item[:lunch_selection]['choices'].to_h { |choice| [choice['group'], choice['menu_item_id']] } } }
      },
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
    raw = params.dig(:order, :items) || ActionController::Parameters.new
    raise Order::InvalidTransition, 'Selecione pelo menos um produto.' unless raw.is_a?(ActionController::Parameters)
    raise Order::InvalidTransition, 'Demasiados produtos num pedido.' if raw.keys.size > 200

    items = raw.to_unsafe_h.filter_map do |id, qty|
      raise Order::InvalidTransition, 'Quantidade inválida.' unless qty.to_s.match?(/\A\d{1,2}\z/)
      next if qty.to_i.zero?

      item = @table.establishment.menu_items.includes(:category).find(id)
      raise Order::InvalidTransition, "#{item.name} já não está disponível." unless item.available? && !item.archived? && item.category.visible_to_customers?

      { menu_item_id: item.id, name: item.name, quantity: qty.to_i, unit_price: item.price, line_total: item.price * qty.to_i }
    end

    items.concat(selected_lunch_items)
    raise Order::InvalidTransition, 'Selecione pelo menos um produto.' if items.empty?
    items
  end

  def selected_lunch_items
    individual = params.dig(:order, :lunch_items) || ActionController::Parameters.new
    raise Order::InvalidTransition, 'Pratos de almoço inválidos.' unless individual.is_a?(ActionController::Parameters) && individual.keys.size <= 200
    combos = JSON.parse(params.dig(:order, :lunch_combos).presence || '[]')
    raise Order::InvalidTransition, 'Menus de almoço inválidos.' unless combos.is_a?(Array) && combos.size <= 10
    selected = individual.to_unsafe_h.reject { |_id, quantity| quantity.to_s == '0' }
    return [] if selected.empty? && combos.empty?
    menu = @table.establishment.lunch_menu
    raise Order::InvalidTransition, 'O almoço já não está disponível.' unless menu
    rows = selected.map { |id, quantity| menu.selection(kind: 'individual', menu_item_id: id, quantity: quantity) }
    rows + combos.map do |combo|
      raise Order::InvalidTransition, 'Menu de almoço inválido.' unless combo.is_a?(Hash) && combo['choices'].is_a?(Hash)
      menu.selection(kind: 'combo', quantity: combo['quantity'], choices: combo['choices'])
    end
  rescue JSON::ParserError, TypeError, ArgumentError
    raise Order::InvalidTransition, 'Seleção de almoço inválida.'
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
