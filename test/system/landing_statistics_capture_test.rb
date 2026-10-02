require 'application_system_test_case'

class LandingStatisticsCaptureTest < ApplicationSystemTestCase
  test 'captures the real statistics dashboard with clearly labeled demonstration data' do
    venue, table, product = build_venue
    venue.update!(name: 'Café do Largo', plan: 'management')
    product.update!(name: 'Baguete de frango')
    manager = venue_user(venue)

    4.times do |index|
      order = build_order(table, product, customer: "landing-stats-#{index}")
      order.order_items.each do |item|
        item.update!(status: 'accepted', paid_quantity: item.quantity)
      end
      order.update!(status: 'served', served_at: Time.current, total: 30,
                    paid_at: Time.current, paid_by_user: manager)
      order.payments.create!(user: manager, amount: 30, payment_method: 'card',
                             paid_at: index.hours.ago)
    end

    visit login_path
    fill_in 'Email', with: manager.email
    fill_in 'Palavra-passe', with: 'Test-password-123'
    click_on 'Entrar'
    visit staff_reports_path(tab: 'statistics', analysis: 'revenue', metric: 'total', view: 'day', date: Date.current.iso8601)
    assert_text '120,00 €'
    page.execute_script("document.querySelector('.report-stat-grid').scrollIntoView({block: 'start'})")
    browser = page.driver.browser
    browser.execute_cdp('Emulation.setDeviceMetricsOverride',
      width: 1180, height: 760, deviceScaleFactor: 2, mobile: false)
    page.save_screenshot(Rails.root.join('tmp/screenshots/landing-statistics.png'))
  ensure
    browser&.execute_cdp('Emulation.clearDeviceMetricsOverride')
  end
end
