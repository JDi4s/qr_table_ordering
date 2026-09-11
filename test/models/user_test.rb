require "test_helper"

class UserTest < ActiveSupport::TestCase
  test 'deleted team members keep a historical identity' do
    venue, = build_venue
    staff = venue_user(venue, role: 'staff')

    staff.update!(active: false, deleted_at: Time.current)
    assert staff.deleted?
    assert_equal 'staff (eliminado)', staff.display_identity
    assert_not staff.venue_access?
  end
end
