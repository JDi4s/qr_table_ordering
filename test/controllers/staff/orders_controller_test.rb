require 'test_helper'
class Staff::OrdersControllerTest < ActionDispatch::IntegrationTest
  test 'anonymous users must sign in' do
    get staff_orders_path
    assert_redirected_to login_path
  end
  test 'paying a complete order keeps the table open at its next unpaid order' do
    venue, table, product = build_venue
    order = build_order(table, product)
    next_order = build_order(table, product, customer: 'customer-b')
    [order, next_order].each(&:finalize_review!)
    sign_in(venue_user(venue))

    patch pay_selected_staff_order_path(order), params: {
      payment_method: 'cash', items: order.order_items.to_h { |item| [item.id.to_s, item.quantity] }
    }

    assert order.reload.paid?
    assert_not next_order.reload.paid?
    assert_redirected_to staff_table_path(table, open_order: next_order.id, anchor: "order-#{next_order.id}")
    follow_redirect!
    assert_response :success
    assert_select "details#order-#{next_order.id}[open]"
  end

  test 'partial payment keeps the current order open' do
    venue, table, product = build_venue
    order = build_order(table, product)
    order.finalize_review!
    sign_in(venue_user(venue))

    patch pay_selected_staff_order_path(order), params: {
      payment_method: 'cash', items: { order.order_items.first.id.to_s => 1 }
    }

    assert_not order.reload.paid?
    assert_redirected_to staff_table_path(table, open_order: order.id, anchor: "order-#{order.id}")
  end

  test 'paying the final order returns to active tables' do
    venue, table, product = build_venue
    order = build_order(table, product)
    order.finalize_review!
    sign_in(venue_user(venue))

    patch pay_selected_staff_order_path(order), params: {
      payment_method: 'cash', items: order.order_items.to_h { |item| [item.id.to_s, item.quantity] }
    }

    assert order.reload.paid?
    assert_redirected_to active_staff_tables_path
  end
  test 'pay all pays only the outstanding balance and stays at the table' do
    venue, table, product = build_venue
    order = build_order(table, product)
    next_order = build_order(table, product, customer: 'customer-b')
    [order, next_order].each(&:finalize_review!)
    user = venue_user(venue)
    order.pay_item!(order.order_items.first.id, 1, user)
    sign_in(user)

    get staff_table_path(table, open_order: order.id)
    assert_select "#order-#{order.id} button[name='pay_all'][value='1']", text: /Pagar todo o pedido/
    assert_select "#order-#{order.id} .payment-all-button", text: /20,00/

    assert_difference('Payment.count', 1) do
      patch pay_selected_staff_order_path(order), params: {
        payment_method: 'cash', pay_all: '1', items: { order.order_items.last.id.to_s => 0 }
      }
    end

    assert order.reload.paid?
    assert_equal 20.to_d, order.payments.order(:id).last.amount
    assert_equal 'cash', order.payments.order(:id).last.payment_method
    assert_not next_order.reload.paid?
    assert_redirected_to staff_table_path(table, open_order: next_order.id, anchor: "order-#{next_order.id}")
  end
end
