require 'test_helper'

class MenuImportIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @source, _, @product = build_venue
    @destination = Establishment.create!(name: 'Destino', slug: "destino-#{SecureRandom.hex(4)}")
    @admin = User.create!(email: "admin-#{SecureRandom.hex(4)}@example.com", password: 'Test-password-123', role: 'platform_admin')
  end
  def review_quote
    post review_admin_establishment_menu_import_path(@destination), params: { source_id: @source.id, product_ids: [@product.id] }
    assert_response :success
    Nokogiri::HTML(response.body).at_css('input[name="quote"]')['value']
  end
  test 'admin reviews selection imports once and never writes when previewing' do
    sign_in(@admin)
    get admin_establishments_path
    assert_select "a[href='#{new_admin_establishment_menu_import_path(@destination)}']", text: 'Importar menu'
    get new_admin_establishment_menu_import_path(@destination, source_id: @source.id)
    assert_response :success
    assert_select 'input[name="product_ids[]"][checked]'
    quote = nil
    assert_no_difference('MenuItem.count') { quote = review_quote }
    assert_difference('MenuItem.count', 1) { post admin_establishment_menu_import_path(@destination), params: { quote: quote } }
    assert_redirected_to admin_establishments_path
    assert_no_difference('MenuItem.count') { post admin_establishment_menu_import_path(@destination), params: { quote: quote } }
    get admin_establishments_path
    assert_select "a[href='#{new_admin_establishment_menu_import_path(@destination)}']", count: 0
  end
  test 'staff cannot import and tampered or wrong destination quotes do not write' do
    sign_in(venue_user(@source))
    get new_admin_establishment_menu_import_path(@destination)
    assert_redirected_to staff_orders_path
    sign_in(@admin)
    quote = review_quote
    assert_no_difference('MenuItem.count') { post admin_establishment_menu_import_path(@destination), params: { quote: quote + 'tampered' } }
    other = Establishment.create!(name: 'Outro', slug: "outro-#{SecureRandom.hex(4)}")
    assert_no_difference('MenuItem.count') { post admin_establishment_menu_import_path(other), params: { quote: quote } }
  end
end
