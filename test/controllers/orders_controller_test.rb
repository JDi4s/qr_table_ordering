require 'test_helper'
class OrdersControllerTest < ActionDispatch::IntegrationTest
  test 'unknown table tokens do not expose a menu' do
    get new_table_order_path('invalid-token')
    assert_response :not_found
  end
end
