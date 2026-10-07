require 'test_helper'

class TableVisitsChannelTest < ActionCable::Channel::TestCase
  setup { @venue, @table, = build_venue }

  test 'customer can only listen to status for an available QR' do
    stub_connection current_user: nil, customer_token: 'alice', support_establishment: nil
    subscribe table_token: @table.qr_token
    assert subscription.confirmed?
    assert_has_stream "table_access_#{@table.id}"
  end

  test 'unknown QR does not fall through to a staff stream' do
    stub_connection current_user: venue_user(@venue), customer_token: 'alice', support_establishment: nil
    subscribe table_token: 'missing'
    assert subscription.rejected?
  end

  test 'staff cannot choose a different establishment' do
    stub_connection current_user: venue_user(@venue), customer_token: nil, support_establishment: nil
    subscribe establishment_id: -1
    assert_has_stream "table_activation_#{@venue.id}"
  end

  test 'anonymous and suspended staff cannot subscribe' do
    stub_connection current_user: nil, customer_token: nil, support_establishment: nil
    subscribe
    assert subscription.rejected?
  end
end
