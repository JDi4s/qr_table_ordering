require 'application_system_test_case'

class LandingLanguageTest < ApplicationSystemTestCase
  test 'visitor can switch the landing to English and open the login' do
    visit root_path
    assert_selector 'img[src="/landing-preview/staff.png"]'
    assert page.evaluate_script('Array.from(document.images).every(image => image.complete && image.naturalWidth > 0)'), 'Landing screenshots did not load'
    click_on 'EN'

    assert_text 'Table orders, made simple.'
    assert_selector 'html[lang="en"]'
    assert_current_path '/?lang=en'
    click_on 'Log in', match: :first
    assert_current_path login_path
    assert_text 'Bem-vindo à Bocato.'
  end
end
