require 'test_helper'
class OrdersChannelTest < ActionCable::Channel::TestCase
  setup do
    @venue, @table, @product = build_venue
  end
  test 'customer stream is limited to session identity and active QR' do
    stub_connection current_user: nil, customer_token: 'alice'
    subscribe table_token: @table.qr_token
    assert subscription.confirmed?
    assert_has_stream "table_#{@table.id}_customer_alice"
  end
  test 'staff subscription rejects anonymous users' do
    stub_connection current_user: nil, customer_token: 'alice'
    subscribe
    assert subscription.rejected?
  end
  test 'staff cannot select another establishment by signed stream parameter' do
    user = venue_user(@venue)
    stub_connection current_user: user, customer_token: nil
    subscribe signed_stream_name: 'another-establishment'
    assert_has_stream @venue.staff_stream
  end
  test 'inactive QR cannot subscribe' do
    @table.update!(active: false)
    stub_connection current_user: nil, customer_token: 'alice'
    subscribe table_token: @table.qr_token
    assert subscription.rejected?
  end
end
