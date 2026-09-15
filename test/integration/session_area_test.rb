require 'test_helper'

class SessionAreaTest < ActionDispatch::IntegrationTest
  setup do
    @venue, @table, @product = build_venue
    @manager = venue_user(@venue)
    @owner = User.create!(email: "session-owner-#{SecureRandom.hex(4)}@example.com", password: 'Test-password-123', role: 'platform_admin')
  end

  test 'old staff page never logs an administrator out without a support intervention' do
    sign_in(@manager)
    get staff_menu_path
    assert_response :success
    sign_in(@owner)

    get staff_menu_path
    assert_redirected_to admin_establishments_path
    assert_response :see_other
    get admin_establishments_path
    assert_response :success
  end

  test 'automatic staff push registration cannot log administrator out or change subscription' do
    sign_in(@owner)
    assert_no_difference 'StaffPushSubscription.count' do
      post staff_push_subscription_path, params: { subscription: { endpoint: 'https://example.com/push', keys: { p256dh: 'key', auth: 'secret' } } }, as: :json
    end
    assert_response :forbidden
    assert_includes response.headers['Cache-Control'], 'no-store'
    get admin_establishments_path
    assert_response :success
  end

  test 'stale venue form cannot mutate an order as an administrator' do
    order = build_order(@table, @product)
    sign_in(@owner)
    patch staff_order_path(order), params: { status: 'accepted' }
    assert_redirected_to admin_establishments_path
    assert order.reload.pending?
    get admin_establishments_path
    assert_response :success
  end

  test 'old administrator page preserves the new manager login' do
    sign_in(@owner)
    get admin_establishments_path
    assert_response :success
    sign_in(@manager)
    get admin_establishments_path
    assert_redirected_to staff_orders_path
    get staff_orders_path
    assert_response :success
  end

  test 'administrator push request is forbidden under the manager login without logging out' do
    sign_in(@manager)
    assert_no_difference 'StaffPushSubscription.count' do
      post admin_push_subscription_path, params: { subscription: { endpoint: 'https://example.com/push', keys: { p256dh: 'key', auth: 'secret' } } }, as: :json
    end
    assert_response :forbidden
    get staff_orders_path
    assert_response :success
  end

  test 'management pages bypass HTTP and Turbo snapshots' do
    sign_in(@owner)
    get admin_establishments_path
    assert_includes response.headers['Cache-Control'], 'no-store'
    assert_select 'meta[name="turbo-cache-control"][content="no-cache"]'
    sign_in(@manager)
    get staff_orders_path
    assert_includes response.headers['Cache-Control'], 'no-store'
    assert_select 'meta[name="turbo-cache-control"][content="no-cache"]'
  end
end
