require 'test_helper'
class Staff::CategoriesControllerTest < ActionDispatch::IntegrationTest
  test 'anonymous users must sign in' do
    get new_staff_category_path
    assert_redirected_to login_path
  end
end
