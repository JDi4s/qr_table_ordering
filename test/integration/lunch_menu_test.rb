require 'test_helper'
class LunchMenuIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @venue, @table, @product = build_venue
    @manager = venue_user(@venue)
    @menu = @venue.create_lunch_menu!(active: true, weekdays: (0..6).to_a, starts_at: '00:00', ends_at: '23:59',
      individual_offers: [{ 'menu_item_id' => @product.id, 'price' => '8.50' }], combo_enabled: true,
      combo_groups: LunchMenu::GROUPS.keys.to_h { |key| [key, [{ 'menu_item_id' => @product.id, 'supplement' => key == 'drink' ? '1' : '0' }]] })
    TableVisit.activate_for!(@table)
  end
  def quote_for(order)
    get new_table_order_path(@table)
    post review_table_orders_path(@table), params: { order: order }
    assert_response :success
    Nokogiri::HTML(response.body).at_css('input[name="quote"]')['value']
  end
  def choices
    %w[soup plate drink].to_h { |key| [key, @product.id] }
  end
  test 'complete menu and avulso submit and can be fully paid without duplicate revenue' do
    quote = quote_for(lunch_items: { @product.id => '1' }, lunch_combos: [{ quantity: 1, choices: choices, priceCents: 1 }].to_json)
    assert_select '.lunch-order-choices', text: /#{@product.name}/
    assert_difference('Order.count') { post table_orders_path(@table), params: { quote: quote } }
    order = @table.orders.last
    assert_equal BigDecimal('21.50'), order.total
    assert_equal 2, order.order_items.size
    combo = order.order_items.find_by(menu_item_id: nil)
    assert_equal 'Menu completo', combo.display_name
    order.finalize_review!
    order.serve!
    order.mark_paid!(@manager, payment_method: 'cash')
    assert_equal BigDecimal('21.50'), order.payments.sum(:amount)
    data = ReportExtract.new(establishment: @venue, period: ReportPeriod.new({ view: 'day' })).data
    assert_equal '21,50 €', data[:stats][0][1]
    assert_equal '2', data[:stats][2][1]
    assert_equal ['Menu completo', 1, '13,00 €'], data[:sections].find { |s| s[:title] == 'Top 5 produtos por quantidade' }[:rows].find { |r| r.first == 'Menu completo' }
    assert combo.reload.paid?
    assert order.table_visit.reload.closed_at
    get my_table_orders_path(@table)
    assert_response :success
    assert_select '.lunch-order-choices'
  end
  test 'old quote rejects changed configuration or elapsed lunch period' do
    quote = quote_for(lunch_combos: [{ quantity: 1, choices: choices }].to_json)
    @menu.update!(combo_price: 15)
    assert_no_difference('Order.count') { post table_orders_path(@table), params: { quote: quote } }
    assert_response :redirect
    quote = quote_for(lunch_items: { @product.id => 1 })
    @menu.update!(active: false)
    assert_no_difference('Order.count') { post table_orders_path(@table), params: { quote: quote } }
  end
  test 'only managers configure lunch and snapshot polls do not replace customer cookies' do
    get new_table_order_path(@table)
    get table_menu_snapshot_path(@table)
    assert_response :success
    assert_nil response.headers['Set-Cookie']
    assert_select 'turbo-stream[target="customer_menu"]'
    sign_in(venue_user(@venue, role: 'staff'))
    get edit_staff_lunch_menu_path
    assert_response :forbidden
    sign_in(@manager)
    get edit_staff_lunch_menu_path
    assert_response :success
    @product.update!(product_kind: 'plate')
    patch staff_lunch_menu_path, params: { lunch_menu: { active: '1', weekdays: ['4'], starts_at: '12:00', ends_at: '15:00', individual_enabled: '1', combo_enabled: '0', combo_price: '12' }, groups: { '0' => { key: 'plate', name: 'Prato', types: 'plate', enabled: '1' } }, combo_options: { plate: { @product.id => { selected: '1', supplement: '0' } } } }
    assert_response :redirect
    assert_not @menu.reload.individual_enabled?
    assert @menu.combo_enabled?
    assert_equal @product.id, @menu.combo_groups['plate'].first['menu_item_id']
    assert_equal BigDecimal('10'), @product.reload.price
  end

  test 'scheduled snapshot removes lunch at closing without ending the table visit' do
    @menu.update!(starts_at: '12:00', ends_at: '15:00')
    travel_to Time.utc(2026, 10, 8, 13, 59) do
      get new_table_order_path(@table)
      assert_select '.customer-menu-scopes .menu-root-tab span', text: 'Almoço'
    end
    travel_to Time.utc(2026, 10, 8, 14) do
      assert_no_difference('TableVisit.count') { get table_menu_snapshot_path(@table) }
      assert_nil response.headers['Set-Cookie']
      doc = Nokogiri::HTML.fragment(response.body)
      assert_not_includes doc.css('template').inner_html, '>Almoço</span>'
      assert @table.current_table_visit.open?
    end
  end

  test 'complete menus are visible to staff responsible for one of their selected products' do
    @venue.update!(production_areas_limit: 2)
    kitchen = @venue.production_areas.create!(name: 'Cozinha')
    @product.update!(production_area: kitchen)
    employee = venue_user(@venue, role: 'staff')
    employee.production_areas << kitchen
    quote = quote_for(lunch_combos: [{ quantity: 1, choices: choices }].to_json)
    post table_orders_path(@table), params: { quote: quote }
    sign_in(employee)
    get staff_orders_path
    assert_response :success
    assert_select '.staff-order-items', text: /Menu completo/
  end
end

