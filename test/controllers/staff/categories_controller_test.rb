require "test_helper"

class Staff::CategoriesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get staff_categories_index_url
    assert_response :success
  end

  test "should get show" do
    get staff_categories_show_url
    assert_response :success
  end

  test "should get new" do
    get staff_categories_new_url
    assert_response :success
  end

  test "should get edit" do
    get staff_categories_edit_url
    assert_response :success
  end
end
