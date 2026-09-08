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

  test 'product rename preserves ordered name and product deletion is blocked' do
    old_name = @product.name
    @product.update!(name: 'Nome novo')
    assert_equal old_name, @order.order_items.first.display_name
    assert_not @product.destroy
  end
end
