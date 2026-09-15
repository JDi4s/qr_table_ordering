require 'test_helper'

class SupportLiveTest < ActionDispatch::IntegrationTest
  setup do
    @venue, = build_venue
    @manager = venue_user(@venue)
    @owner = User.create!(email: "live-support-#{SecureRandom.hex(4)}@example.com", password: 'Test-password-123', role: 'platform_admin')
    @ticket = @venue.support_tickets.create!(created_by: @manager, subject: 'Ajuda com o menu', category: 'menu')
  end

  test 'manager reply updates both conversations and alerts only support' do
    sign_in(@manager)
    streams = ["support_ticket_#{@ticket.id}_admin", "support_ticket_#{@ticket.id}_staff"]
    captured = streams.map { |stream| broadcasts(stream).size }
    notifications = broadcasts("support_notifications_user_#{@manager.id}").size
    assert_broadcasts("support_notifications_user_#{@owner.id}", 1) do
      post staff_support_ticket_messages_path(@ticket), params: { support_ticket_message: { body: 'Mensagem em tempo real' } }
    end
    assert_response :see_other
    streams.each_with_index do |stream, index|
      messages = broadcasts(stream).drop(captured[index]).map { |payload| ActiveSupport::JSON.decode(payload) }
      assert messages.any? { |html| html.include?('action="append"') && html.include?('Mensagem em tempo real') }
      assert_not messages.any? { |html| html.include?("target=\"support_ticket_reply_#{@ticket.id}\"") }, 'Incoming messages must preserve the draft composer'
    end
    assert_equal notifications, broadcasts("support_notifications_user_#{@manager.id}").size
  end

  test 'support response alerts only managers of the correct establishment' do
    other_venue, = build_venue
    other_manager = venue_user(other_venue)
    sign_in(@owner)
    assert_broadcasts("support_notifications_user_#{other_manager.id}", 0) do
      assert_broadcasts("support_notifications_user_#{@manager.id}", 1) do
        post admin_support_ticket_messages_path(@ticket), params: { support_ticket_message: { body: 'Vamos ajudar.' } }
      end
    end
    assert_response :see_other
    assert_equal 'waiting_establishment', @ticket.reload.status
  end

  test 'resolving ticket changes the live status and hides the reply form' do
    sign_in(@owner)
    stream = "support_ticket_#{@ticket.id}_staff"
    previous = broadcasts(stream).size
    patch admin_support_ticket_path(@ticket), params: { support_ticket: { status: 'resolved' } }
    assert_response :see_other
    messages = broadcasts(stream).drop(previous).map { |payload| ActiveSupport::JSON.decode(payload) }
    assert messages.any? { |html| html.include?("target=\"support_ticket_status_#{@ticket.id}\"") && html.include?('Resolvido') }
    assert messages.any? { |html| html.include?("target=\"support_ticket_reply_#{@ticket.id}\"") && html.include?('Este pedido está resolvido') }
  end

  test 'ticket pages expose authenticated live streams and stable message targets' do
    sign_in(@manager)
    get staff_support_ticket_path(@ticket)
    assert_select 'turbo-cable-stream-source[channel="SupportTicketsChannel"][data-scope="ticket"]'
    assert_select "#support_ticket_messages_#{@ticket.id}"
    assert_select '#support_notifications'
    get staff_support_tickets_path
    assert_select '#support_ticket_list'
  end

  test 'invalid message never creates an alert or a message broadcast' do
    sign_in(@manager)
    assert_broadcasts("support_notifications_user_#{@owner.id}", 0) do
      assert_no_difference 'SupportTicketMessage.count' do
        post staff_support_ticket_messages_path(@ticket), params: { support_ticket_message: { body: '' } }
      end
    end
    assert_response :see_other
  end
end
