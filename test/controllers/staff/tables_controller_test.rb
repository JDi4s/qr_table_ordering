require 'test_helper'
class Staff::TablesControllerTest < ActionDispatch::IntegrationTest
  test 'anonymous users must sign in' do
    get staff_tables_path
    assert_redirected_to login_path
  end

  test 'manager sees compact QR actions while inactive tables keep editing available' do
    venue, active_table, = build_venue
    inactive_table = venue.tables.create!(number: 2, active: false)
    sign_in(venue_user(venue))

    get staff_tables_path

    assert_response :success
    assert_select '.staff-qr-overview', text: /1\/#{venue.table_limit}/
    assert_select '.staff-qr-card', count: 2
    assert_select ".staff-qr-card[data-number='#{active_table.number}']" do
      assert_select "a[href='#{qr_code_staff_table_path(active_table)}']", text: 'Ver QR'
      assert_select "a[href='#{qr_code_staff_table_path(active_table, download: 1)}']", text: 'Descarregar'
      assert_select "a[href='#{new_table_order_path(active_table)}']", text: 'Abrir menu'
    end
    assert_select ".staff-qr-card[data-number='#{inactive_table.number}']" do
      assert_select '.category-status', text: 'Desativada'
      assert_select 'a', text: 'Ver QR', count: 0
      assert_select '.staff-qr-edit-form', count: 1
    end
  end
end
