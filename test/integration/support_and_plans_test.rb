require 'test_helper'

class SupportAndPlansTest < ActionDispatch::IntegrationTest
  setup do
    @venue, @table, @product = build_venue
    @manager = venue_user(@venue)
    @owner = User.create!(email: "owner-#{SecureRandom.hex(4)}@example.com", password: 'Test-password-123', role: 'platform_admin', name: 'João')
  end

  test 'essential plan exposes today and the last seven days only' do
    sign_in(@manager)

    get staff_reports_path(tab: 'statistics', view: 'month', month: '2025-01')

    assert_response :success
    assert_includes response.body, 'Plano Essencial'
    assert_includes response.body, 'Últimos 7 dias'
    assert_not_includes response.body, 'O que queres analisar?'
  end

  test 'manager opens a support ticket and platform owner can answer it' do
    sign_in(@manager)
    assert_difference(['SupportTicket.count', 'SupportTicketMessage.count'], 1) do
      post staff_support_tickets_path, params: { support_ticket: { subject: 'Preciso de ajuda', category: 'menu', priority: 'normal', message: 'Não consigo alterar o menu.' } }
    end
    ticket = SupportTicket.last
    assert_redirected_to staff_support_ticket_path(ticket)
    follow_redirect!
    assert_response :success
    assert_includes response.body, 'Não consigo alterar o menu.'

    delete logout_path
    sign_in(@owner)
    get admin_support_ticket_path(ticket)
    assert_response :success
    assert_includes response.body, 'Não consigo alterar o menu.'
    post admin_support_ticket_messages_path(ticket), params: { support_ticket_message: { body: 'Já estamos a verificar.' } }
    assert_redirected_to admin_support_ticket_path(ticket)
    follow_redirect!
    assert_response :success
    assert_includes response.body, 'Já estamos a verificar.'
    assert_equal 'waiting_establishment', ticket.reload.status
  end

  test 'wrong account is redirected instead of seeing a forbidden page' do
    sign_in(@manager)

    get admin_establishments_path

    assert_redirected_to staff_orders_path
  end

  test 'support changes configuration but cannot operate an order' do
    order = build_order(@table, @product)
    sign_in(@owner)
    post admin_support_sessions_path, params: { establishment_id: @venue.id, reason: 'Pedido do gerente para corrigir o menu' }
    support_session = SupportSession.last
    assert_redirected_to staff_menu_path

    get staff_menu_path
    assert_response :success
    assert_includes response.body, 'Modo Suporte'

    patch staff_order_path(order), params: { status: 'accepted' }
    assert_response :see_other
    assert order.reload.pending?

    assert_difference('MenuItem.count', 1) do
      post staff_menu_items_path, params: { menu_item: { name: 'Criado pelo suporte', price: 2, category_id: @product.category_id } }
    end
    assert AuditEvent.where(user: @owner, action: 'menu_item_created').exists?

    delete admin_support_session_path(support_session)
    assert_redirected_to admin_establishments_path
    assert support_session.reload.ended_at.present?
  end
end
