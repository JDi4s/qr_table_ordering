require 'application_system_test_case'

class LandingLanguageTest < ApplicationSystemTestCase
  test 'visitor can switch the landing to English and open the login' do
    visit root_path
    click_on 'EN'

    assert_text 'Table orders, made simple.'
    assert_selector 'html[lang="en"]'
    assert_current_path '/?lang=en'
    click_on 'Log in', match: :first
    assert_current_path login_path
    assert_text 'Bem-vindo à Bocato.'
  end
end
