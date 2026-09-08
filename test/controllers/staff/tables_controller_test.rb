require 'test_helper'
class Staff::TablesControllerTest < ActionDispatch::IntegrationTest
  test 'anonymous users must sign in' do
    get staff_tables_path
    assert_redirected_to login_path
  end
end
