require 'test_helper'
class OrderTest < ActiveSupport::TestCase
  setup do
    @venue, @table, @product = build_venue
    @order = build_order(@table, @product)
  end

  test 'partial rejection removes value and waits only after staff finalizes' do
    @order.review_item!(@order.order_items.first.id, 'denied', reason: 'Esgotado')
    assert @order.reload.pending?
    assert_equal 20, @order.total
    @order.finalize_review!
    assert @order.reload.needs_customer_action?
    assert_equal ['accepted', 'denied'], @order.order_items.pluck(:status).sort
    @order.accept_remaining!
    assert @order.reload.accepted?
    assert_equal 20, @order.total
  end

  test 'all denied finishes without customer confirmation' do
    @order.order_items.each { |item| @order.review_item!(item.id, 'denied', reason: 'Esgotado') }
    @order.finalize_review!
    assert @order.reload.denied?
    assert_equal 0, @order.total
    assert_raises(Order::InvalidTransition) { @order.accept_remaining! }
  end

  test 'proposal and revised price need customer acceptance' do
    @order.review_item!(@order.order_items.first.id, 'accepted', description: 'Sem queijo', price: '8.50')
    @order.finalize_review!
    assert @order.reload.needs_customer_action?
    assert_equal BigDecimal('28.50'), @order.total
    assert_raises(Order::InvalidTransition) { @order.serve! }
    @order.accept_remaining!
    @order.serve!
    assert @order.reload.served?
    assert @order.served_at
  end

  test 'revised price cannot be concealed by clearing proposal' do
    item = @order.order_items.first
    @order.review_item!(item.id, 'accepted', description: 'Sem queijo', price: '8')
    assert_raises(Order::InvalidTransition) { @order.review_item!(item.id, 'accepted', price: '8', description: '') }
  end

  test 'terminal states cannot be reopened or canceled' do
    @order.finalize_review!
    assert @order.reload.accepted?
    assert_raises(Order::InvalidTransition) { @order.reject!(nil, customer: true) }
    @order.serve!
    assert_raises(Order::InvalidTransition) { @order.finalize_review! }
    assert_raises(Order::InvalidTransition) { @order.review_item!(@order.order_items.first.id, 'denied', reason: 'Não') }
  end

  test 'cancel marks all items and total consistently' do
    @order.review_item!(@order.order_items.first.id, 'accepted')
    @order.reject!(nil, customer: true)
    assert @order.reload.denied?
    assert_equal ['denied'], @order.order_items.distinct.pluck(:status)
    assert_equal 0, @order.total
  end

  test 'denial requires a reason and quantities must be positive integers' do
    assert_raises(ActiveRecord::RecordInvalid) { @order.review_item!(@order.order_items.first.id, 'denied') }
    assert_equal 30, @order.reload.total
    assert_not @order.order_items.first.update(quantity: 1.5)
    assert_not @order.order_items.first.update(quantity: 0)
  end

  test 'foreign venue products cannot be associated with an order' do
    other, other_table, foreign_product = build_venue
    assert_raises(ActiveRecord::RecordInvalid) do
      @order.order_items.create!(menu_item: foreign_product, quantity: 1, unit_price: 10)
    end
  end

  test 'broadcasts append new orders and render customer actions without controller variables' do
    messages = capture_broadcasts(@venue.staff_stream) { build_order(@table, @product) }
    assert messages.any? { |message| message.include?('action="append"') && message.include?('staff_orders_live') }
    @order.review_item!(@order.order_items.first.id, 'denied', reason: 'Esgotado')
    messages = capture_broadcasts(@order.customer_stream) { @order.finalize_review! }
    assert messages.any? { |message| message.include?('Aceitar este pedido atualizado') }
    other = build_order(@table, @product, customer: 'customer-b')
    assert_not_equal @order.customer_stream, other.customer_stream
  end

  test 'product rename preserves ordered name and deletion is blocked only while the order is ongoing' do
    old_name = @product.name
    @product.update!(name: 'Nome novo')
    assert_equal old_name, @order.order_items.first.display_name
    assert_raises(Order::InvalidTransition) { @product.destroy! }

    @order.finalize_review!
    @order.serve!
    @product.destroy!
    assert_nil @order.order_items.first.reload.menu_item
    assert_equal old_name, @order.order_items.first.display_name
  end

  test 'accepted order can be marked paid and leaves the unpaid table list' do
    cashier = venue_user(@venue, role: 'staff')
    @order.finalize_review!

    @order.mark_paid!(cashier)

    assert @order.reload.paid?
    assert_equal cashier, @order.paid_by_user
    assert_not @table.orders.unpaid.exists?(@order.id)
    assert_raises(Order::InvalidTransition) { @order.mark_paid!(cashier) }
  end

  test 'full payment broadcasts removal of the table from active tables' do
    cashier = venue_user(@venue, role: 'staff')
    @order.finalize_review!

    messages = capture_broadcasts(@venue.staff_stream) { @order.mark_paid!(cashier) }

    assert messages.any? { |message| message.include?('action="remove"') && message.include?("table_#{@table.id}") }
  end

  test 'accepted order supports paying only part of an item quantity' do
    cashier = venue_user(@venue, role: 'staff')
    @order.finalize_review!
    item = @order.order_items.second

    @order.pay_item!(item.id, 1, cashier)

    assert_equal 1, item.reload.paid_quantity
    assert_equal 1, item.remaining_quantity
    assert_equal BigDecimal('20'), @order.reload.outstanding_total
    assert_not @order.paid?

    @order.pay_item!(item.id, 1, cashier)
    assert_not @order.reload.paid?

    @order.mark_paid!(cashier)
    assert @order.reload.paid?
    assert_equal 0, @order.outstanding_total
  end

  test 'payments keep an item-level movement and method' do
    cashier = venue_user(@venue, role: 'staff')
    @order.finalize_review!

    @order.pay_item!(@order.order_items.first.id, 1, cashier, payment_method: 'card')

    payment = @order.payments.order(:created_at).last
    assert_equal 'card', payment.payment_method
    assert_equal BigDecimal('10'), payment.amount
    assert_equal 1, payment.payment_items.first.quantity
    assert_equal cashier, payment.user
  end

  test 'customer cancellation is allowed for three minutes and then expires' do
    assert @order.cancellable_by_customer?

    travel 4.minutes do
      assert_raises(Order::InvalidTransition) { @order.reject!(nil, customer: true) }
    end

    assert @order.reload.pending?
  end

  test 'served or paid orders are preserved when removed' do
    assert_not @order.preserve_when_removed?
    @order.finalize_review!
    @order.serve!
    assert @order.reload.preserve_when_removed?

    paid = build_order(@table, @product, customer: 'customer-paid')
    paid.finalize_review!
    paid.mark_paid!(venue_user(@venue, role: 'staff'))
    assert paid.reload.preserve_when_removed?
  end
end
