require 'test_helper'
require 'minitest/mock'

class StaffPushNotifierTest < ActiveSupport::TestCase
  test 'orders notify every registered device of active staff in the same establishment' do
    venue, table, product = build_venue
    manager = venue_user(venue)
    inactive = venue_user(venue)
    inactive.update!(active: false)
    other_venue, = build_venue
    foreign = venue_user(other_venue)
    [manager, inactive, foreign].each do |user|
      2.times { |number| user.staff_push_subscriptions.create!(endpoint: "https://push.example/#{user.id}/#{number}", p256dh: 'key', auth: 'auth') }
    end
    order = build_order(table, product)
    delivered = []
    notifier = StaffPushNotifier.new

    notifier.stub(:configured?, true) do
      WebPush.stub(:payload_send, ->(**arguments) { delivered << arguments[:endpoint] }) do
        notifier.notify_order(order)
      end
    end

    assert_equal manager.staff_push_subscriptions.pluck(:endpoint).sort, delivered.sort
  end
end
