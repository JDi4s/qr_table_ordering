require "test_helper"

class Staff::MenuItemsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get staff_menu_items_index_url
    assert_response :success
  end

  test "should get show" do
    get staff_menu_items_show_url
    assert_response :success
  end

  test "should get new" do
    get staff_menu_items_new_url
    assert_response :success
  end

  test "should get edit" do
    get staff_menu_items_edit_url
    assert_response :success
  end
end
