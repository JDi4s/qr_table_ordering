require 'test_helper'
class Staff::MenuItemsControllerTest < ActionDispatch::IntegrationTest
  test 'anonymous users must sign in' do
    get new_staff_menu_item_path
    assert_redirected_to login_path
  end
end
