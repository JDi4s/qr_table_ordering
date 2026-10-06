require 'test_helper'

class ReportExtractTest < ActiveSupport::TestCase
  setup do
    @venue, @table, @product = build_venue
    @user = venue_user(@venue)
    @period = ReportPeriod.new({ view: 'custom', from: '2026-10-01', to: '2026-10-03' }, today: Date.new(2026, 10, 6))
  end

  def payment(table = @table, product = @product, user: @user, at: '2026-10-02 12:30', quantity: 1, amount: 8)
    order = build_order(table, product)
    item = order.order_items.first
    item.update!(unit_price: 8, original_unit_price: 10)
    p = order.payments.create!(user: user, amount: amount, paid_at: Time.zone.parse(at), payment_method: 'cash')
    p.payment_items.create!(order_item: item, quantity: quantity, unit_price: 8, amount: amount)
    p
  end

  def section(data, title) = data[:sections].find { |s| s[:title] == title }

  test 'partial payments use captured quantities and exclude voids foreign venues and outside dates' do
    payment
    payment(at: '2026-10-04 12:00', amount: 100)
    payment(amount: 20).update!(voided_at: Time.zone.parse('2026-10-03 12:00'), void_reason: 'Correção')
    other, table, product = build_venue
    payment(table, product, user: venue_user(other), amount: 500)
    data = ReportExtract.new(establishment: @venue, period: @period).data
    assert_equal '8,00 €', data[:stats][0][1]
    assert_equal '1', data[:stats][2][1]
    assert_equal '2,67 €', data[:stats][3][1]
    assert_equal [[@product.name, 1, '8,00 €']], section(data, 'Top 5 produtos por quantidade')[:rows]
    assert_equal '100,0%', section(data, 'Faturação por categoria')[:rows].first.last
    assert_equal ['Reduções de preço concedidas', '2,00 €'], section(data, 'Anulações, cancelamentos e descontos')[:rows].last
    assert_equal '1 / 20,00 €', section(data, 'Anulações, cancelamentos e descontos')[:rows][1][1]
    assert_equal '12h - 13h / 8,00 €', section(data, 'Destaques do período')[:rows][2][1]
    assert_equal 1, data[:payment_rows].size
  end

  test 'orders are counted once across partial payments and employee filter affects all receipt metrics' do
    first = payment
    second = first.order.payments.create!(user: @user, amount: 16, paid_at: first.paid_at + 1.hour, payment_method: 'card')
    second.payment_items.create!(order_item: first.order.order_items.last, quantity: 2, unit_price: 8, amount: 16)
    payment(user: venue_user(@venue))
    data = ReportExtract.new(establishment: @venue, period: @period, employee: @user).data
    assert_equal '24,00 €', data[:stats][0][1]
    assert_equal '1', data[:stats][1][1]
    assert_equal '3', data[:stats][2][1]
    assert_equal 1, section(data, 'Faturação e pedidos por mesa')[:rows].first[1]
  end

  test 'empty report avoids misleading comparison percentages and shows zero sale products separately' do
    data = ReportExtract.new(establishment: @venue, period: @period).data
    assert_equal '0,00 €', data[:stats][0][1]
    assert_equal 'Sem comparação', section(data, 'Comparação de períodos')[:rows].first[2]
    assert_equal [[@product.name, 0]], section(data, 'Produtos atuais sem vendas no período')[:rows]
    assert_equal 'Sem dados', section(data, 'Destaques do período')[:rows].first[1]
    assert BrandedReportPdf.new(data).render.start_with?('%PDF')
  end

  test 'payments are grouped by Lisbon date and 08h to 11h band' do
    payment(at: '2026-10-01 08:30')
    data = ReportExtract.new(establishment: @venue, period: @period).data
    row = section(data, 'Consulta por dia e faixa horária')[:rows].first
    assert_equal ['Quinta', '08h - 11h', 1, '8,00 €'], row
    p = payment(at: '2026-09-30 23:30 UTC') # 00:30 on 1 October in Lisbon.
    assert_equal Date.new(2026, 10, 1), p.paid_at.in_time_zone.to_date
    data = ReportExtract.new(establishment: @venue, period: @period).data
    assert_equal '16,00 €', data[:stats][0][1]
  end

  test 'PDF supports long Unicode labels repeated table headers and all payment movements' do
    p = payment
    data = ReportExtract.new(establishment: @venue, period: @period).data
    data[:payment_rows] = Array.new(100) { |i| ['02/10/2026', '12:30', i.to_s, '1', 'Funcionário com nome longo e acentuação', 'Dinheiro', '8,00 €'] }
    data[:sections] << { title: 'Lista extensa', headers: ['Produto', 'Valor'], rows: Array.new(80) { |i| ["Produto #{i} com descrição longa " * 3, '8,00 €'] } }
    rendered = BrandedReportPdf.new(data).render
    assert rendered.start_with?('%PDF')
    assert_includes rendered, '/Subtype /Image'
  end
end
