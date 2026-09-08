require 'test_helper'
class Staff::OrdersControllerTest < ActionDispatch::IntegrationTest
  test 'anonymous users must sign in' do
    get staff_orders_path
    assert_redirected_to login_path
  end
end
