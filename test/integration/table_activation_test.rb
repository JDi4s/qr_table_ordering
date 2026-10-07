require 'test_helper'

class TableActivationTest < ActionDispatch::IntegrationTest
  setup do
    @venue, @table, @product = build_venue
    @staff = venue_user(@venue, role: 'staff')
    @manager = venue_user(@venue)
  end

  def review_quote(client = self)
    client.post review_table_orders_path(@table), params: { order: { items: { @product.id.to_s => '1' } } }
    assert_equal 200, client.response.status
    Nokogiri::HTML(client.response.body).at_css('input[name="quote"]')['value']
  end

  test 'QR opens menu immediately but only staff activation allows submitting' do
    assert_difference('TableVisit.count', 1) { get new_table_order_path(@table) }
    assert_response :success
    assert_select '.customer-table-access-notice', text: /ainda não está ativa/
    assert_select '.customer-product-card', text: /#{@product.name}/
    quote = review_quote
    assert_select 'button[data-table-access-target="submit"][disabled]', text: 'Enviar pedido'
    assert_no_difference('Order.count') { post table_orders_path(@table), params: { quote: quote } }
    assert_no_difference('ServiceCall.count') { post table_service_calls_path(@table) }
    employee = open_session
    employee.post login_path, params: { email: @staff.email, password: 'Test-password-123' }
    employee.post staff_table_visit_path(@table)
    assert_equal 303, employee.response.status
    get table_access_status_path(@table)
    assert_equal true, response.parsed_body['allowed']
    assert_nil response.headers['Set-Cookie'], 'Status polls must not overwrite a newer visit session'
    assert_difference('Order.count', 1) { post table_orders_path(@table), params: { quote: quote } }
    assert_equal @table.table_visits.last.id, @table.orders.last.table_visit_id
    assert_no_difference('Order.count') { post table_orders_path(@table), params: { quote: quote } }
  end

  test 'closing blocks old quotes even when another visit is already open' do
    TableVisit.activate_for!(@table)
    get new_table_order_path(@table)
    old_quote = review_quote
    old_visit = @table.table_visits.last
    TableVisit.close_for!(@table)
    TableVisit.activate_for!(@table)
    get table_access_status_path(@table)
    assert_equal 'closed', response.parsed_body['state']
    assert_equal false, response.parsed_body['allowed']
    assert_no_difference('Order.count') { post table_orders_path(@table), params: { quote: old_quote } }
    assert old_visit.reload.closed_at
    get new_table_order_path(@table)
    new_quote = review_quote
    assert_no_difference('Order.count') { post table_orders_path(@table), params: { quote: old_quote } }
    assert_difference('Order.count', 1) { post table_orders_path(@table), params: { quote: new_quote } }
  end

  test 'two browsers share activation but never share customer orders' do
    first = open_session
    second = open_session
    first.get new_table_order_path(@table)
    second.get new_table_order_path(@table)
    assert_equal 1, @table.table_visits.count
    TableVisit.activate_for!(@table)
    quote = review_quote(first)
    first.post table_orders_path(@table), params: { quote: quote }
    assert_no_difference('Order.count') { second.post table_orders_path(@table), params: { quote: quote } }
    second.get my_table_orders_path(@table)
    assert_not_includes second.response.body, "Pedido ##{@table.orders.last.id}"
  end

  test 'activation endpoints isolate venues and forbid anonymous callers' do
    post staff_table_visit_path(@table)
    assert_redirected_to login_path
    sign_in(@staff)
    other, other_table, = build_venue
    TableVisit.request_for!(other_table)
    post staff_table_visit_path(other_table)
    assert_response :not_found
    delete staff_table_visit_path(other_table)
    assert_response :not_found
    get staff_table_visits_path, headers: { 'Accept' => 'application/json' }
    assert_response :success
    assert_nil response.headers['Set-Cookie'], 'Status polls must not restore an older staff login'
    assert_empty response.parsed_body['pending_ids']
    assert_equal [@table.id], response.parsed_body['states'].map(&:first)
    @venue.update!(active: false)
    post staff_table_visit_path(@table)
    assert_redirected_to login_path
    assert_empty @table.table_visits
  end

  test 'staff closes empty visits and cannot close outstanding orders' do
    TableVisit.activate_for!(@table)
    sign_in(@staff)
    delete staff_table_visit_path(@table)
    assert @table.table_visits.last.closed_at
    visit = TableVisit.activate_for!(@table)
    build_order(@table, @product).update!(table_visit: visit)
    delete staff_table_visit_path(@table)
    assert visit.reload.open?
  end
end
