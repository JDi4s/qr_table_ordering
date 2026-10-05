require 'test_helper'

class Staff::PushSubscriptionsControllerTest < ActionDispatch::IntegrationTest
  test 'registering and removing one device preserves other devices and logout is scoped to this session' do
    venue, = build_venue
    manager = venue_user(venue)
    other_device = manager.staff_push_subscriptions.create!(endpoint: 'https://push.example/other', p256dh: 'key', auth: 'auth')
    sign_in(manager)

    post staff_push_subscription_path, params: { subscription: { endpoint: 'https://push.example/current', keys: { p256dh: 'key', auth: 'auth' } } }, as: :json
    assert_response :success
    assert_equal 2, manager.staff_push_subscriptions.count

    delete staff_push_subscription_path, params: { endpoint: 'https://push.example/current' }, as: :json
    assert_response :no_content
    assert StaffPushSubscription.exists?(other_device.id)

    post staff_push_subscription_path, params: { subscription: { endpoint: 'https://push.example/current', keys: { p256dh: 'key', auth: 'auth' } } }, as: :json
    delete logout_path
    assert_redirected_to login_path
    assert_equal [other_device.endpoint], manager.staff_push_subscriptions.pluck(:endpoint)
  end

  test 'a device cannot remove another users subscription or all devices without an endpoint' do
    venue, = build_venue
    manager = venue_user(venue)
    other = venue_user(venue)
    subscription = other.staff_push_subscriptions.create!(endpoint: 'https://push.example/foreign', p256dh: 'key', auth: 'auth')
    sign_in(manager)

    assert_no_difference('StaffPushSubscription.count') do
      delete staff_push_subscription_path, as: :json
      assert_response :unprocessable_entity
      delete staff_push_subscription_path, params: { endpoint: subscription.endpoint }, as: :json
      assert_response :no_content
    end
  end
end
