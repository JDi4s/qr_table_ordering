require 'test_helper'
class TablesControllerTest < ActionDispatch::IntegrationTest
  test 'no public table directory exists' do
    get '/tables'
    assert_response :not_found
  end
end
