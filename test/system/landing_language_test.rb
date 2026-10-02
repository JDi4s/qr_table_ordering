require 'application_system_test_case'

class LandingLanguageTest < ApplicationSystemTestCase
  test 'visitor can switch the landing to English and open the login' do
    visit root_path
    assert_selector 'img[src="/landing-preview/staff-v2.png"]'
    assert page.evaluate_script('Array.from(document.images).every(image => image.complete && image.naturalWidth > 0)'), 'Landing screenshots did not load'
    browser = page.driver.browser
    browser.execute_cdp('Emulation.setDeviceMetricsOverride',
      width: 1280, height: 900, deviceScaleFactor: 1, mobile: false)
    assert_equal 1280, page.evaluate_script('window.innerWidth')
    page.execute_script("document.documentElement.style.scrollBehavior = 'auto'")
    page.save_screenshot(Rails.root.join('tmp/screenshots/landing-desktop-v2.png'))
    page.execute_script("document.querySelector('#produto').scrollIntoView({block: 'center'})")
    page.save_screenshot(Rails.root.join('tmp/screenshots/landing-product-desktop.png'))
    browser.execute_cdp('Emulation.setDeviceMetricsOverride',
      width: 390, height: 800, deviceScaleFactor: 2, mobile: false)
    assert_equal 390, page.evaluate_script('window.innerWidth')
    page.execute_script('window.scrollTo(0, 0)')
    page.save_screenshot(Rails.root.join('tmp/screenshots/landing-mobile-v2.png'))
    page.execute_script("document.querySelector('.hero-visual').scrollIntoView({block: 'center'})")
    page.save_screenshot(Rails.root.join('tmp/screenshots/landing-hero-mobile.png'))
    page.execute_script("document.querySelectorAll('.product-phone')[0].scrollIntoView({block: 'center'})")
    page.save_screenshot(Rails.root.join('tmp/screenshots/landing-product-first-mobile.png'))
    page.execute_script("document.querySelectorAll('.product-phone')[1].scrollIntoView({block: 'center'})")
    page.save_screenshot(Rails.root.join('tmp/screenshots/landing-product-second-mobile.png'))
    browser.execute_cdp('Emulation.clearDeviceMetricsOverride')
    click_on 'EN'

    assert_text 'Table orders, made simple.'
    assert_selector 'html[lang="en"]'
    assert_current_path '/?lang=en'
    click_on 'Log in', match: :first
    assert_current_path login_path
    assert_text 'Bem-vindo ao Bocato.'
  end
end
