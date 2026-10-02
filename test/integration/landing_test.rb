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
    assert_select 'img[src="/landing-preview/staff-v2.png"]'
    assert_select 'form[action="/landing_requests"]'

    get login_path
    assert_response :success
    assert_select 'form[action="/login"]'
  end

  test 'public request reaches platform admin and cannot be changed by staff' do
    attributes = {
      first_name: 'Ana', last_name: 'Silva', business_email: 'ana@cafe.example',
      phone: '+351 912 345 678', region: 'Braga', business_type: 'cafe'
    }

    assert_difference 'LandingRequest.count', 1 do
      post landing_requests_path, params: { landing_request: attributes }
    end
    assert_redirected_to root_path(sent: 1, anchor: 'pedido')
    lead = LandingRequest.last
    assert_equal 'new', lead.status

    venue, = build_venue
    sign_in venue_user(venue)
    get admin_landing_requests_path
    assert_redirected_to staff_orders_path
    patch admin_landing_request_path(lead), params: { landing_request: { status: 'closed' } }
    assert_redirected_to staff_orders_path
    assert_equal 'new', lead.reload.status

    delete logout_path
    admin = User.create!(name: 'Admin', email: 'landing-admin@example.com',
                         password: 'Test-password-123', role: 'platform_admin')
    sign_in admin
    get admin_landing_requests_path
    assert_response :success
    assert_select 'h2', text: 'Ana Silva'
    patch admin_landing_request_path(lead), params: { landing_request: { status: 'contacted' } }
    assert_redirected_to admin_landing_request_path(lead)
    assert_equal 'contacted', lead.reload.status
  end

  test 'invalid or automated requests do not create a record' do
    assert_no_difference 'LandingRequest.count' do
      post landing_requests_path, params: { landing_request: {
        first_name: 'Ana', last_name: 'Silva', business_email: 'wrong', phone: '123',
        region: 'Braga', business_type: 'cafe'
      } }
    end
    assert_response :unprocessable_entity
    assert_select '.lead-error'

    assert_no_difference 'LandingRequest.count' do
      post landing_requests_path, params: { website: 'https://spam.example' }
    end
    assert_redirected_to root_path(sent: 1)
  end
end
