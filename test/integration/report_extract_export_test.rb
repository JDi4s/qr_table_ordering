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
    get export_staff_reports_path
    assert_response :forbidden
  end

  test 'CSV uses the complete extract and respects the selected employee and dates' do
    other = venue_user(@venue)
    [@manager, other].each do |user|
      order = build_order(@table, @product)
      order.finalize_review!
      order.mark_paid!(user)
    end
    sign_in(@manager)
    get export_staff_reports_path(view: 'day', date: Date.current.iso8601, employee_id: @manager.id)
    assert_response :success
    assert_equal 'text/csv', response.media_type
    rows = CSV.parse(response.body.delete_prefix("\uFEFF"), col_sep: ';')
    assert_includes rows, ['Faturação recebida', '30,00 €']
    assert_includes rows, ['Artigos vendidos', '3']
    assert_includes rows, ['Dias e horários']
    assert_includes rows, ['Faturação por categoria']
    detail = rows.drop(rows.index(['Pagamentos detalhados']) + 2).take_while(&:present?)
    assert_equal 1, detail.size
    assert_equal @manager.display_identity, detail.first[4]
    get export_staff_reports_path(view: 'day', date: (Date.current - 3).iso8601)
    rows = CSV.parse(response.body.delete_prefix("\uFEFF"), col_sep: ';')
    assert_includes rows, ['Faturação recebida', '0,00 €']
    assert_includes rows, ['Cliques em Avaliar no Google', 'Sem registo']
  end
end
