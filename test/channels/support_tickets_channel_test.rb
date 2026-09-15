require 'test_helper'

class SupportTicketsChannelTest < ActionCable::Channel::TestCase
  setup do
    @venue, = build_venue
    @manager = venue_user(@venue)
    @ticket = @venue.support_tickets.create!(created_by: @manager, subject: 'Ajuda', category: 'menu')
    @owner = User.create!(email: "support-#{SecureRandom.hex(4)}@example.com", password: 'Test-password-123', role: 'platform_admin')
  end

  test 'manager subscribes to own ticket and personal notifications' do
    stub_connection current_user: @manager, support_establishment: nil
    subscribe scope: 'ticket', ticket_id: @ticket.id
    assert subscription.confirmed?
    assert_has_stream "support_ticket_#{@ticket.id}_staff"
  end

  test 'another establishment cannot subscribe to the ticket' do
    other_venue, = build_venue
    stub_connection current_user: venue_user(other_venue), support_establishment: nil
    subscribe scope: 'ticket', ticket_id: @ticket.id
    assert subscription.rejected?
  end

  test 'ordinary staff cannot access support streams' do
    stub_connection current_user: venue_user(@venue, role: 'staff'), support_establishment: nil
    subscribe scope: 'notifications'
    assert subscription.rejected?
  end

  test 'platform administrator receives the admin ticket stream' do
    stub_connection current_user: @owner, support_establishment: nil
    subscribe scope: 'ticket', ticket_id: @ticket.id
    assert_has_stream "support_ticket_#{@ticket.id}_admin"
  end

  test 'inactive account cannot subscribe' do
    @manager.update!(active: false)
    stub_connection current_user: @manager, support_establishment: nil
    subscribe scope: 'notifications'
    assert subscription.rejected?
  end

  test 'suspended establishment cannot subscribe' do
    @venue.update!(active: false)
    stub_connection current_user: @manager, support_establishment: nil
    subscribe scope: 'list'
    assert subscription.rejected?
  end

  test 'support intervention cannot subscribe to platform ticket streams' do
    stub_connection current_user: @owner, support_establishment: @venue
    subscribe scope: 'notifications'
    assert subscription.rejected?
  end

  test 'invalid list filter is rejected' do
    stub_connection current_user: @owner, support_establishment: nil
    subscribe scope: 'list', status: 'anything'
    assert subscription.rejected?
  end
end
