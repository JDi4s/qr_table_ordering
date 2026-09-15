require 'application_system_test_case'

class SessionAreaSystemTest < ApplicationSystemTestCase
  test 'changing account then visiting an old area preserves the current login' do
    venue, = build_venue
    manager = venue_user(venue)
    owner = User.create!(email: "browser-session-#{SecureRandom.hex(4)}@example.com", password: 'Test-password-123', role: 'platform_admin')

    browser_login(manager)
    visit staff_menu_path
    assert_text 'Menu'
    browser_login(owner)
    visit staff_menu_path
    assert_current_path admin_establishments_path
    assert_selector '.admin-header'

    browser_login(manager)
    visit admin_establishments_path
    assert_current_path staff_orders_path
    assert_no_button 'Entrar'
  end

  private

  def browser_login(user)
    visit login_path
    fill_in 'Email', with: user.email
    fill_in 'Palavra-passe', with: 'Test-password-123'
    click_on 'Entrar'
    assert_no_button 'Entrar'
  end
end
