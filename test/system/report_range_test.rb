require 'application_system_test_case'

class ReportRangeTest < ApplicationSystemTestCase
  teardown do
    page.current_window.resize_to(1280, 900)
  end

  test 'mobile custom range survives navigation and export links' do
    venue, = build_venue
    venue.update!(plan: 'management')
    manager = venue_user(venue)
    page.current_window.resize_to(390, 844)
    visit login_path
    fill_in 'Email', with: manager.email
    fill_in 'Palavra-passe', with: 'Test-password-123'
    click_on 'Entrar'
    visit staff_reports_path
    find('.report-custom-range summary').click
    first, last = Date.current - 5, Date.current - 2
    fill_in 'Data inicial', with: first
    fill_in 'Data final', with: last
    click_on 'Aplicar período'
    assert_selector '.report-period-button', text: "#{first.strftime('%d/%m/%Y')} - #{last.strftime('%d/%m/%Y')}"
    find('.report-choice-grid a', text: 'Produtos').click
    assert_selector 'input[name=from]', visible: :all
    assert_equal first.iso8601, find('input[name=from]', visible: :all).value
    find('.report-export-menu summary').click
    assert_selector "a[href*='pdf'][href*='from=#{first.iso8601}'][href*='to=#{last.iso8601}']"
    assert page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth'), 'Mobile range has horizontal overflow'
    page.save_screenshot(Rails.root.join('results/report-range-mobile.png'))
  end
end
