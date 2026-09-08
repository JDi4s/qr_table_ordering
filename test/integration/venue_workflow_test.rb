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
    assert_response :not_found
  end

  test 'staff cannot create tables manage users or alter contracts' do
    sign_in(venue_user(@venue, role: 'staff'))
    post staff_tables_path, params: { table: { number: 2 } }
    assert_response :forbidden
    get staff_users_path
    assert_response :forbidden
    get admin_establishments_path
    assert_response :forbidden
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
    assert_difference('Order.count', 1) { post table_orders_path(@table), params: { quote: quote } }
    order = @table.orders.last
    assert_equal 20, order.total
    assert_no_difference('Order.count') { post table_orders_path(@table), params: { quote: quote } }
    get my_table_orders_path(@table)
    assert_response :success
    assert_includes response.body, "Pedido ##{order.id}"
    second = open_session
    second.get my_table_orders_path(@table)
    assert_not_includes second.response.body, "Pedido ##{order.id}"
    second.post cancel_table_order_path(@table, order)
    assert_equal 404, second.response.status
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

  test 'staff decisions render whole detail and customer accepts proposal end to end' do
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
    assert order.reload.needs_customer_action?
    get my_table_orders_path(@table)
    assert_includes response.body, 'Sem queijo'
    post accept_remaining_table_order_path(@table, order)
    assert order.reload.accepted?
    assert_equal 17, order.total
    staff.patch staff_order_path(order), params: { status: 'served' }
    assert order.reload.served?
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
end
