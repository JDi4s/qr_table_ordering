require 'test_helper'

class LandingTest < ActionDispatch::IntegrationTest
  test 'public home shows the product and links to the existing login' do
    get root_path

    assert_response :success
    assert_select 'html[lang="pt-PT"]'
    assert_select 'h1', text: /Mais pedidos à mesa/
    assert_select 'a.login[href="/login"]', text: 'Entrar'
    assert_select 'button[data-language="pt"][aria-pressed="true"]', text: 'PT'
    assert_select 'button[data-language="en"][aria-pressed="false"]', text: 'EN'
    assert_select 'img[src="/landing-preview/staff.png"]'

    get login_path
    assert_response :success
    assert_select 'form[action="/login"]'
  end
end
