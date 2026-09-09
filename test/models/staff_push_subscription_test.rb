require 'test_helper'

class StaffPushSubscriptionTest < ActiveSupport::TestCase
  test 'a staff member has only one registered device' do
    venue, = build_venue
    user = venue_user(venue, role: 'staff')
    user.create_staff_push_subscription!(endpoint: 'https://push.example/one', p256dh: 'public-key', auth: 'auth-key')

    duplicate = user.build_staff_push_subscription(endpoint: 'https://push.example/two', p256dh: 'public-key', auth: 'auth-key')
    assert_not duplicate.valid?
  end
end
