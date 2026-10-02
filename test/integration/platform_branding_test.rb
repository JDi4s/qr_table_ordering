require 'test_helper'

class PlatformBrandingTest < ActionDispatch::IntegrationTest
  test 'login presents the Bocato identity and icons' do
    get login_path

    assert_response :success
    assert_select 'title', text: 'Bocato — Pedidos por QR'
    assert_select 'img.platform-logo[alt="Bocato"]', count: 1
    assert_select 'h1', text: 'Bem-vindo ao Bocato.'
    assert_select 'link[rel="icon"][href="/bocato-icon-v4-32.png"]', count: 1
    assert_select 'link[rel="apple-touch-icon"][href="/bocato-icon-v4-180.png"]', count: 1
    assert_not_includes response.body, 'scan, pede e paga'
  end

  test 'web app manifest uses the Bocato identity and install icons' do
    get '/manifest.json'

    assert_response :success
    manifest = JSON.parse(response.body)
    assert_equal 'Bocato — Gestão', manifest.fetch('name')
    assert_equal 'Bocato', manifest.fetch('short_name')
    assert_equal ['/bocato-icon-v4-192.png', '/bocato-icon-v4-512.png'], manifest.fetch('icons').map { |icon| icon.fetch('src') }
  end
end
