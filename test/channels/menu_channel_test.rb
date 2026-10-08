require 'test_helper'

class MenuChannelTest < ActionCable::Channel::TestCase
  setup { @venue, @table, @product = build_venue }

  test 'QR selects its own public menu and receives a reconnect snapshot' do
    stub_connection current_user: nil, customer_token: 'customer-a'
    subscribe table_token: @table.qr_token, signed_stream_name: 'another-venue'
    assert subscription.confirmed?
    assert_has_stream CustomerMenuBroadcast.stream_name(@venue)
    assert_includes transmissions.last, 'target="customer_menu"'
    assert_includes transmissions.last, @product.name
  end

  test 'anonymous connection and disabled QR cannot subscribe' do
    stub_connection current_user: nil, customer_token: nil
    subscribe table_token: @table.qr_token
    assert subscription.rejected?
    @table.update!(active: false)
    stub_connection current_user: nil, customer_token: 'customer-a'
    subscribe table_token: @table.qr_token
    assert subscription.rejected?
  end
end
