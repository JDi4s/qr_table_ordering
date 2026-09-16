require 'test_helper'
class VenueWorkflowTest < ActionDispatch::IntegrationTest
  setup do
    @venue, @table, @product = build_venue
    @other, @other_table, @other_product = build_venue
    @manager = venue_user(@venue)
    @other_order = build_order(@other_table, @other_product)
  end

  test 'manager pages render and data belongs only to current venue' do
    sign_in(@manager)
    [staff_orders_path, staff_menu_path, staff_tables_path, staff_users_path, new_staff_menu_item_path, new_staff_category_path, edit_staff_settings_path, history_staff_orders_path].each do |path|
      get path
      assert_response :success, path
      assert_not_includes response.body, @other_product.name
    end
    get staff_order_path(@other_order)
    assert_response :not_found
    patch staff_order_item_path(@other_order.order_items.first), params: { order_item: { status: 'denied', denial_reason: 'Não' } }
    assert_response :not_found
    get qr_code_staff_table_path(@other_table)
    assert_response :not_found
    post staff_menu_items_path, params: { menu_item: { name: 'Intruso', price: 10, category_id: @other_product.category_id } }
    assert_response :unprocessable_entity
  end

  test 'staff cannot create tables manage users or alter contracts' do
    sign_in(venue_user(@venue, role: 'staff'))
    post staff_tables_path, params: { table: { number: 2 } }
    assert_response :forbidden
    get staff_users_path
    assert_response :forbidden
    get admin_establishments_path
    assert_redirected_to staff_orders_path
  end

  test 'manager can remove individual members and tables' do
    staff = venue_user(@venue, role: 'staff')
    empty_table = @venue.tables.create!(number: 2)
    sign_in(@manager)

    assert_no_difference('User.count') { delete staff_user_path(staff) }
    assert_response :see_other
    assert staff.reload.deleted?
    assert_not staff.active?
    assert_no_difference('Table.count') { delete staff_table_path(empty_table) }
    assert_response :see_other
    assert empty_table.reload.deleted?
  end

  test 'orders do not have a staff deletion route' do
    order = build_order(@table, @product, customer: 'permanent-history')

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(staff_order_path(order), method: :delete)
    end
  end

  test 'staff cancellation keeps the order in history' do
    order = build_order(@table, @product, customer: 'cancelled-history')
    sign_in(@manager)

    assert_no_difference('Order.count') do
      patch staff_order_path(order), params: { status: 'denied', denial_reason: 'Produto indisponível' }
    end

    assert order.reload.denied?
    assert_equal 'Produto indisponível', order.cancellation_reason
    assert order.cancelled_at.present?
    get history_staff_orders_path
    assert_response :success
    assert_includes response.body, "PEDIDO ##{order.id}"
  end

  test 'history separates service state from payment state and shows the real order total' do
    order = build_order(@table, @product, customer: 'served-unpaid-history')
    order.finalize_review!
    order.serve!
    sign_in(@manager)

    get history_staff_orders_path

    assert_response :success
    assert_select ".history-order", text: /PEDIDO ##{order.id}/ do
      assert_select '.order-status-served', text: 'Servido'
      assert_select '.payment-status-unpaid', text: 'Por pagar'
      assert_select '.history-order-total strong', text: /Total 30,00 €/
      assert_select '.history-order-total small', text: /Recebido 0,00 € · Por pagar 30,00 €/
    end
  end

  test 'history remains after members and tables are removed' do
    staff = venue_user(@venue, role: 'staff')
    AuditLogger.record(user: staff, action: 'test_activity')
    order = build_order(@table, @product, customer: 'preserved-order')
    order.finalize_review!
    order.mark_paid!(staff)
    sign_in(@manager)

    assert_no_difference('User.count') { delete staff_user_path(staff) }
    assert_response :see_other
    assert Order.exists?(order.id)
    assert_equal staff, order.payments.first.user
    assert_no_difference('Table.count') { delete staff_table_path(@table) }
    assert_response :see_other
    assert @table.reload.deleted?
    assert_equal order, @table.orders.first
  end

  test 'manager cannot remove a table or member involved in open service' do
    staff = venue_user(@venue, role: 'staff')
    call = @table.service_calls.create!(status: 'claimed', assigned_user: staff)
    build_order(@table, @product, customer: 'open-order')
    sign_in(@manager)

    assert_no_changes -> { staff.reload.deleted_at } do
      delete staff_user_path(staff)
    end
    assert_response :see_other
    assert_no_changes -> { @table.reload.deleted_at } do
      delete staff_table_path(@table)
    end
    assert_response :see_other
    assert call.reload.claimed?
  end

  test 'staff can log in with username without an email' do
    staff = venue_user(@venue, role: 'staff')
    staff.update!(email: nil, username: 'balcao')

    post login_path, params: { identifier: 'balcao', password: 'Test-password-123' }

    assert_redirected_to staff_orders_path
  end

  test 'platform owner can create tenant and manager and manually upgrade' do
    owner = User.create!(email: 'owner@example.com', password: 'Test-password-123', role: 'platform_admin')
    sign_in(owner)
    get admin_establishments_path
    assert_response :success
    post admin_establishments_path, params: { establishment: { name: 'Novo café', slug: 'novo', table_limit: 50, monthly_fee: '100.00', active: '1' }, manager: { name: 'Gerente', email: 'new@example.com', password: 'Test-password-123' } }
    assert_response :redirect
    venue = Establishment.find_by!(slug: 'novo')
    assert_equal 10000, venue.monthly_fee_cents
    assert venue.users.first.manager?
    patch admin_establishment_path(venue), params: { establishment: { table_limit: 120, monthly_fee: '150.00' } }
    assert_equal 120, venue.reload.table_limit
    assert_equal 15000, venue.monthly_fee_cents
  end

  test 'customer review is signed idempotent and scoped to their browser' do
    get new_table_order_path(@table)
    assert_response :success
    assert_includes response.body, @product.name
    assert_not_includes response.body, @other_product.name
    post review_table_orders_path(@table), params: { order: { items: { @product.id.to_s => '2' }, note: 'Sem tomate' } }
    assert_response :success
    quote = css_select('input[name="quote"]').first['value']
    assert_select '#order_note', value: 'Sem tomate'
    get new_table_order_path(@table)
    assert_response :success
    assert_select "input[name='order[items][#{@product.id}]'][value='2']"
    assert_difference('Order.count', 1) { post table_orders_path(@table), params: { quote: quote } }
    order = @table.orders.last
    assert_equal 20, order.total
    assert_no_difference('Order.count') { post table_orders_path(@table), params: { quote: quote } }
    get my_table_orders_path(@table)
    assert_response :success
    assert_includes response.body, "Pedido ##{order.id}"
    assert_includes response.body, 'Total do pedido'
    assert_not_includes response.body, 'Total provisório'
    assert_not_includes response.body, 'pago(s)'
    assert_not_includes response.body, 'por pagar'
    second = open_session
    second.get my_table_orders_path(@table)
    assert_not_includes second.response.body, "Pedido ##{order.id}"
    second.post cancel_table_order_path(@table, order)
    assert_equal 404, second.response.status
  end

  test 'reserved uncategorized storage never appears in the customer menu' do
    uncategorized = @venue.categories.create!(name: 'Sem categoria', available: true)
    uncategorized.menu_items.create!(name: 'Produto por organizar', price: 2, available: true)

    get new_table_order_path(@table)

    assert_response :success
    assert_not_includes response.body, 'Sem categoria'
    assert_not_includes response.body, 'Produto por organizar'
  end

  test 'price change or tampered quote is not silently accepted' do
    get new_table_order_path(@table)
    post review_table_orders_path(@table), params: { order: { items: { @product.id.to_s => '1' } } }
    quote = css_select('input[name="quote"]').first['value']
    @product.update!(price: 12)
    assert_no_difference('Order.count') { post table_orders_path(@table), params: { quote: quote } }
    assert_no_difference('Order.count') { post table_orders_path(@table), params: { quote: quote + 'x' } }
  end

  test 'invalid quantity foreign products and inactive QR cannot place orders' do
    get new_table_order_path(@table)
    post review_table_orders_path(@table), params: { order: { items: { @product.id.to_s => '1.5' } } }
    assert_response :redirect
    post review_table_orders_path(@table), params: { order: { items: { @other_product.id.to_s => '1' } } }
    assert_response :not_found
    @table.update!(active: false)
    get new_table_order_path(@table)
    assert_response :not_found
    post table_service_calls_path(@table)
    assert_response :not_found
  end

  test 'staff decisions accept changes directly and render them to the customer' do
    get new_table_order_path(@table)
    post review_table_orders_path(@table), params: { order: { items: { @product.id.to_s => '2' } } }
    quote = css_select('input[name="quote"]').first['value']
    post table_orders_path(@table), params: { quote: quote }
    order = @table.orders.last
    staff = open_session
    staff.post login_path, params: { email: @manager.email, password: 'Test-password-123' }
    staff.get staff_order_path(order)
    assert_equal 200, staff.response.status
    staff.patch staff_order_item_path(order.order_items.first), params: { order_item: { status: 'accepted', proposed_description: 'Sem queijo', unit_price: '8.50' } }
    assert_equal 303, staff.response.status
    staff.patch staff_order_path(order), params: { status: 'accepted' }
    assert order.reload.accepted?
    get my_table_orders_path(@table)
    assert_includes response.body, 'Sem queijo'
    assert_equal 17, order.total
    staff.patch staff_order_path(order), params: { status: 'served' }
    assert order.reload.served?
  end

  test 'staff accepts an order without leaving the current board' do
    order = build_order(@table, @product)
    sign_in(@manager)

    patch staff_order_path(order),
      params: { status: 'accepted' },
      headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

    assert_response :no_content
    assert order.reload.accepted?
  end

  test 'suspension blocks existing staff session and customer endpoints' do
    sign_in(@manager)
    @venue.update!(active: false)
    get staff_orders_path
    assert_redirected_to login_path
    get new_table_order_path(@table)
    assert_response :not_found
    post table_service_calls_path(@table)
    assert_response :not_found
  end

  test 'service call endpoint deduplicates and correct venue can claim' do
    2.times { post table_service_calls_path(@table) }
    assert_equal 1, @table.service_calls.count
    sign_in(@manager)
    call = @table.service_calls.first
    patch staff_service_call_path(call), params: { status: 'claimed' }
    assert call.reload.claimed?
    patch staff_service_call_path(call), params: { status: 'resolved' }
    assert call.reload.resolved?
  end

  test 'staff can open active tables and mark an accepted order paid' do
    order = build_order(@table, @product)
    order.finalize_review!
    sign_in(@manager)

    get active_staff_tables_path
    assert_response :success
    assert_includes response.body, "Mesa #{@table.number}"

    patch mark_paid_staff_order_path(order)
    assert_response :redirect
    assert order.reload.paid?

    get active_staff_tables_path
    assert_response :success
    assert_not_includes response.body, "Mesa #{@table.number}"
  end

  test 'staff can pay one quantity and keep the table active for the remainder' do
    order = build_order(@table, @product)
    order.update!(note: 'Croissant sem manteiga')
    order.finalize_review!
    item = order.order_items.second
    sign_in(@manager)

    patch pay_item_staff_order_path(order), params: { order_item_id: item.id, quantity: 1 }

    assert_response :redirect
    assert_equal 1, item.reload.paid_quantity
    assert_not order.reload.paid?

    get staff_table_path(@table)
    assert_response :success
    assert_includes response.body, 'Observações do cliente'
    assert_includes response.body, 'Croissant sem manteiga'
    assert_includes response.body, '1 já pago(s)'
  end

  test 'active tables count only unpaid orders' do
    paid_order = build_order(@table, @product)
    paid_order.finalize_review!
    unpaid_order = build_order(@table, @product, customer: 'customer-b')
    unpaid_order.finalize_review!
    sign_in(@manager)

    patch mark_paid_staff_order_path(paid_order)
    get active_staff_tables_path

    assert_response :success
    assert_select '.table-card p', text: /1 pedido\(s\) em aberto/
    assert_not_includes response.body, '2 pedido(s) em aberto'
  end

  test 'manager pauses service while the menu stays visible and customer actions are blocked' do
    sign_in(@manager)

    patch service_status_staff_settings_path, params: { accepting_orders: '0' }

    assert_redirected_to edit_staff_settings_path
    assert_not @venue.reload.accepting_orders?
    assert AuditEvent.where(establishment: @venue, user: @manager, action: 'service_paused').exists?

    customer = open_session
    customer.get new_table_order_path(@table)
    assert_equal 200, customer.response.status
    assert_includes customer.response.body, @product.name
    assert_includes customer.response.body, 'Serviço temporariamente pausado'
    assert_no_difference('ServiceCall.count') { customer.post table_service_calls_path(@table) }
    assert_no_difference('Order.count') do
      customer.post review_table_orders_path(@table), params: { order: { items: { @product.id.to_s => '1' } } }
    end

    patch service_status_staff_settings_path, params: { accepting_orders: '1' }
    assert @venue.reload.accepting_orders?
    assert AuditEvent.where(establishment: @venue, user: @manager, action: 'service_opened').exists?
  end

  test 'staff cannot change the service status' do
    staff = venue_user(@venue, role: 'staff')
    sign_in(staff)

    patch service_status_staff_settings_path, params: { accepting_orders: '0' }

    assert_response :forbidden
    assert @venue.reload.accepting_orders?
  end

  test 'an order reviewed before a pause cannot be submitted after the service pauses' do
    customer = open_session
    customer.get new_table_order_path(@table)
    customer.post review_table_orders_path(@table), params: { order: { items: { @product.id.to_s => '1' } } }
    quote = Nokogiri::HTML(customer.response.body).at_css('input[name="quote"]')['value']
    @venue.pause_service!(@manager)

    assert_no_difference('Order.count') do
      customer.post table_orders_path(@table), params: { quote: quote }
    end
    assert_equal 303, customer.response.status
    assert_equal new_table_order_url(@table), customer.response.location
  end

  test 'cash cannot close with unpaid tables and closes after all payments are recorded' do
    order = build_order(@table, @product)
    order.finalize_review!
    sign_in(@manager)

    assert_no_difference('CashClosure.count') do
      post close_staff_reports_path, params: { date: Date.current.iso8601 }
    end
    assert_redirected_to staff_reports_path(tab: 'cash', date: Date.current)
    assert_includes flash[:alert], "Mesa #{@table.number}"

    patch mark_paid_staff_order_path(order)
    assert_difference('CashClosure.count', 1) do
      post close_staff_reports_path, params: { date: Date.current.iso8601 }
    end
    assert_redirected_to staff_reports_path(tab: 'cash', date: Date.current)

    closure = @venue.cash_closures.active.find_by!(business_date: Date.current)
    patch reopen_staff_reports_path, params: { date: Date.current.iso8601, reopen_reason: 'Corrigir pagamento' }
    assert_redirected_to staff_reports_path(tab: 'cash', date: Date.current)
    assert closure.reload.reopened?
    assert AuditEvent.where(establishment: @venue, user: @manager, action: 'cash_reopened').exists?

    assert_difference('CashClosure.count', 1) do
      post close_staff_reports_path, params: { date: Date.current.iso8601 }
    end
    assert_equal 1, @venue.cash_closures.active.where(business_date: Date.current).count
  end

  test 'manager voids a payment through the order history and staff cannot do it' do
    order = build_order(@table, @product)
    order.finalize_review!
    order.mark_paid!(@manager, payment_method: 'card')
    payment = order.payments.last
    sign_in(@manager)

    patch void_staff_payment_path(payment), params: { void_reason: 'Método incorreto' }

    assert_redirected_to staff_order_path(order)
    assert payment.reload.voided?
    assert_not order.reload.paid?
    assert AuditEvent.where(establishment: @venue, user: @manager, action: 'payment_voided').exists?

    replacement = order.payments.create!(user: @manager, payment_method: 'cash', amount: 1, paid_at: Time.current)
    staff_session = open_session
    staff = venue_user(@venue, role: 'staff')
    staff_session.post login_path, params: { identifier: staff.login_identifier, password: 'Test-password-123' }
    staff_session.patch void_staff_payment_path(replacement), params: { void_reason: 'Sem autorização' }
    assert_equal 403, staff_session.response.status
    assert_not replacement.reload.voided?
  end

  test 'customer can add more than one suggested item' do
    suggestion = @venue.categories.create!(name: 'Bebidas', available: true).menu_items.create!(name: 'Café', price: 0.85, available: true)
    MenuItemRecommendation.create!(menu_item: @product, recommended_menu_item: suggestion)

    get new_table_order_path(@table)
    post review_table_orders_path(@table), params: { order: { items: { @product.id.to_s => '1' } } }
    assert_response :success
    quote = css_select('input[name="quote"]').first['value']

    post table_orders_path(@table), params: {
      quote: quote,
      suggestion_quantities: { suggestion.id.to_s => '2' }
    }

    order = @table.orders.last
    suggestion_item = order.order_items.find_by!(menu_item_id: suggestion.id)
    assert_equal 2, suggestion_item.quantity
  end
end
