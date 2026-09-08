require 'test_helper'
class ServiceCallTest < ActiveSupport::TestCase
  setup do
    @venue, @table, = build_venue
    @staff = venue_user(@venue, role: 'staff')
    @other_staff = venue_user(@venue, role: 'staff')
  end
  test 'repeated calls are deduplicated and claim ownership enforced' do
    call = ServiceCall.request_for!(@table)
    assert_equal call.id, ServiceCall.request_for!(@table).id
    call.progress!(@staff, 'claimed')
    assert_raises(Order::InvalidTransition) { call.progress!(@other_staff, 'claimed') }
    assert_raises(Order::InvalidTransition) { call.progress!(@other_staff, 'resolved') }
    call.progress!(@staff, 'resolved')
    assert call.reload.resolved?
    assert_raises(Order::InvalidTransition) { ServiceCall.request_for!(@table) }
    travel 61.seconds do
      assert_not_equal call.id, ServiceCall.request_for!(@table).id
    end
  end
  test 'manager may resolve an assigned call and other venues may not' do
    call = ServiceCall.request_for!(@table)
    call.progress!(@staff, 'claimed')
    other, = build_venue
    assert_raises(Order::InvalidTransition) { call.progress!(venue_user(other), 'resolved') }
    call.progress!(venue_user(@venue), 'resolved')
    assert call.reload.resolved?
  end
end
