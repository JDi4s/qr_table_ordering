require "test_helper"

class Staff::TablesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get staff_tables_index_url
    assert_response :success
  end
end
