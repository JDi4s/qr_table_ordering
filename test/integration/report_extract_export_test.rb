require 'test_helper'

class ReportExtractExportTest < ActionDispatch::IntegrationTest
  setup do
    @venue, @table, @product = build_venue
    @venue.update!(plan: 'management')
    @manager = venue_user(@venue)
  end

  test 'manager can select arbitrary range and export branded statistical and cash PDF' do
    sign_in(@manager)
    get staff_reports_path(view: 'custom', from: '2026-10-01', to: '2026-10-03')
    assert_response :success
    assert_select 'input[name=from][value="2026-10-01"]'
    assert_select 'input[name=to][value="2026-10-03"]'
    assert_select 'a[href*="pdf"][href*="from=2026-10-01"]'
    get pdf_staff_reports_path(view: 'custom', from: '2026-10-01', to: '2026-10-03')
    assert_response :success
    assert_equal 'application/pdf', response.media_type
    assert_includes response.body, '/Subtype /Image'
    get pdf_staff_reports_path(tab: 'cash', date: '2026-10-03')
    assert_response :success
    assert_includes response.body, '/Subtype /Image'
  end

  test 'essential plan and staff cannot bypass statistical PDF permissions' do
    sign_in(@manager)
    @venue.update!(plan: 'essential')
    get pdf_staff_reports_path(view: 'custom', from: '2026-10-01', to: '2026-10-03')
    assert_response :see_other
    sign_in(venue_user(@venue, role: 'staff'))
    get pdf_staff_reports_path
    assert_response :forbidden
  end
end
