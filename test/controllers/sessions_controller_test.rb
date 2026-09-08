require 'test_helper'
class SessionsControllerTest < ActionDispatch::IntegrationTest
  test 'login form renders and invalid login is rejected' do
    get login_path
    assert_response :success
    post login_path, params: { email: 'invalid@example.com', password: 'invalid' }
    assert_response :unprocessable_entity
  end
  test 'logout prevents access to staff pages' do
    venue, = build_venue
    sign_in(venue_user(venue))
    delete logout_path
    get staff_orders_path
    assert_redirected_to login_path
  end
end
