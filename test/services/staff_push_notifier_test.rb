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
      WebPush.stub(:payload_send, ->(arguments) { delivered << arguments[:endpoint] }) do
        notifier.notify_order(order)
      end
    end

    assert_equal manager.staff_push_subscriptions.pluck(:endpoint).sort, delivered.sort
  end
end

class PlatformPushNotifierTest < ActiveSupport::TestCase
  test 'support responses notify every manager device and new tickets notify every platform device' do
    venue, = build_venue
    manager = venue_user(venue)
    owner = User.create!(email: "push-owner-#{SecureRandom.hex(4)}@example.com", password: 'Test-password-123', role: 'platform_admin')
    ticket = venue.support_tickets.create!(created_by: manager, subject: 'Ajuda com menu', category: 'menu')
    [manager, owner].each do |user|
      2.times { |number| user.staff_push_subscriptions.create!(endpoint: "https://push.example/#{user.id}/#{number}", p256dh: 'key', auth: 'auth') }
    end
    delivered = []

    PlatformPushNotifier.stub(:configured?, true) do
      WebPush.stub(:payload_send, ->(arguments) { delivered << arguments[:endpoint] }) do
        PlatformPushNotifier.notify_establishment(ticket, nil)
        assert_equal manager.staff_push_subscriptions.pluck(:endpoint).sort, delivered.sort
        delivered.clear
        PlatformPushNotifier.notify_platform(ticket)
        assert_equal owner.staff_push_subscriptions.pluck(:endpoint).sort, delivered.sort
      end
    end
  end
end
