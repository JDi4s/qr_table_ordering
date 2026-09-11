require "test_helper"

class UserTest < ActiveSupport::TestCase
  test 'team members are removable only before operational history exists' do
    venue, = build_venue
    staff = venue_user(venue, role: 'staff')

    assert staff.removable_from_team?

    AuditLogger.record(user: staff, action: 'test_activity')
    assert_not staff.reload.removable_from_team?
  end
end
