require 'test_helper'

class StaffPushSubscriptionTest < ActiveSupport::TestCase
  test 'a user can register several devices and refresh one without replacing the others' do
    venue, = build_venue
    user = venue_user(venue, role: 'staff')
    first = StaffPushSubscription.register_for!(user, endpoint: 'https://push.example/one', p256dh: 'key', auth: 'auth')
    StaffPushSubscription.register_for!(user, endpoint: 'https://push.example/two', p256dh: 'key', auth: 'auth')

    assert_no_difference('StaffPushSubscription.count') do
      StaffPushSubscription.register_for!(user, endpoint: first.endpoint, p256dh: 'renewed', auth: 'auth')
    end

    assert_equal 2, user.staff_push_subscriptions.count
    assert_equal 'renewed', first.reload.p256dh
  end

  test 'the same browser endpoint belongs to one account without deleting other devices' do
    venue, = build_venue
    first_user = venue_user(venue)
    second_user = venue_user(venue)
    StaffPushSubscription.register_for!(first_user, endpoint: 'https://push.example/shared', p256dh: 'key', auth: 'auth')
    StaffPushSubscription.register_for!(first_user, endpoint: 'https://push.example/other', p256dh: 'key', auth: 'auth')

    assert_no_difference('StaffPushSubscription.count') do
      StaffPushSubscription.register_for!(second_user, endpoint: 'https://push.example/shared', p256dh: 'key', auth: 'auth')
    end

    assert_equal ['https://push.example/other'], first_user.staff_push_subscriptions.pluck(:endpoint)
    assert_equal ['https://push.example/shared'], second_user.staff_push_subscriptions.pluck(:endpoint)
  end
end
