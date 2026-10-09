require 'test_helper'
class MenuClarityTest < ActionDispatch::IntegrationTest
  test 'explicitly empty groups remain empty while legacy groups remain compatible' do
    venue, = build_venue
    menu = venue.scheduled_menus.create!(menu_kind: 'lunch', active: false)
    assert_includes menu.groups.map { |group| group['key'] }, 'soup'
    menu.update!(groups_configured: true, group_definitions: [], combo_groups: {})
    assert_empty menu.reload.groups
    assert_not menu.combo_available?
  end
  setup do
    @venue, @table, @product = build_venue
    @manager = venue_user(@venue)
    sign_in @manager
  end

  test 'division requires admin permission and active areas respect its limit' do
    patch staff_service_organization_path, params: { operation: 'division', enabled: '1' }
    assert_not @venue.reload.service_division_enabled?
    patch staff_service_organization_path, params: { operation: 'area', area: { name: 'Área indevida', active: '1', preparation_key: 'counter' } }
    assert_empty @venue.production_areas
    @venue.update!(production_areas_limit: 1)
    patch staff_service_organization_path, params: { operation: 'division', enabled: '1' }
    assert @venue.reload.service_division_enabled?
    assert_equal 1, @venue.production_areas.where(active: true).count
    patch staff_service_organization_path, params: { operation: 'area', area: { name: 'Cozinha', active: '1', preparation_key: 'kitchen' } }
    assert_equal 1, @venue.production_areas.where(active: true).count
    @venue.update!(production_areas_limit: 4)
    patch staff_service_organization_path, params: { operation: 'area', area: { name: 'Bar do piso 1', active: '1', preparation_key: 'counter' } }
    assert_equal 2, @venue.production_areas.where(active: true).count
    assert_not @venue.update(production_areas_limit: 1)
    assert_not @venue.update(production_areas_limit: 0)
  end

  test 'required area cannot be bypassed and uses its routing family' do
    @venue.update!(production_areas_limit: 3, service_division_enabled: true)
    area = @venue.production_areas.create!(name: 'Cozinha de snacks', preparation_key: 'snacks')
    values = { name: 'Sandes', price: 3, category_id: @product.category_id, product_kind: 'snack' }
    assert_no_difference('MenuItem.count') { post staff_menu_items_path, params: { menu_item: values } }
    assert_response :unprocessable_entity
    assert_select 'select[name="menu_item[production_area_id]"][required]'
    post staff_menu_items_path, params: { menu_item: values.merge(production_area_id: area.id, preparation_key: 'counter') }
    assert_response :see_other
    assert_equal 'snacks', @venue.menu_items.find_by!(name: 'Sandes').preparation_key
    patch staff_product_classification_path, params: { product_ids: [@product.id], classification: { product_kind: 'snack' } }
    assert_equal 'unclassified', @product.reload.product_kind
    patch staff_product_classification_path, params: { product_ids: [@product.id], classification: { product_kind: 'snack', production_area_id: area.id } }
    assert_equal area.id, @product.reload.production_area_id
    get staff_menu_path
    assert_select 'a[href=?]', edit_staff_product_classification_path, count: 0
    area.update!(active: false)
    get edit_staff_product_classification_path
    assert_select '.classification-product strong', text: @product.name
  end

  test 'included groups and typed products can be saved together without an optional field' do
    @product.update!(product_kind: 'soup')
    coffee = @product.category.menu_items.create!(name: 'Café', price: 1, product_kind: 'coffee')
    get edit_staff_lunch_menu_path
    assert_select 'input[name$="[optional]"]', count: 0
    assert_select '.scheduled-group-choice', text: /Ovos/, count: 0
    patch staff_lunch_menu_path, params: {
      lunch_menu: { active: '1', weekdays: ['1','2','3','4','5'], starts_at: '12:00', ends_at: '15:00', individual_enabled: '0', combo_enabled: '1', combo_price: '8' },
      groups: { '0' => { key: 'soup', name: 'Sopa', types: 'soup', enabled: '1' }, '1' => { key: 'coffee', name: 'Bebida quente', types: 'coffee', enabled: '0' } },
      combo_options: { soup: { @product.id => { selected: '1', supplement: '0' } }, coffee: { coffee.id => { selected: '1', supplement: '0' } } }
    }
    assert_response :see_other
    menu = @venue.reload.lunch_menu
    assert_equal ['soup'], menu.groups.map { |g| g['key'] }
    assert_equal false, menu.groups.first['optional']
    assert_equal ['soup'], menu.combo_groups.keys
    assert menu.combo_available?
    @product.update!(allergens: ['eggs'])
    assert_includes @product.allergens, 'eggs'
  end

  test 'trash action does not require typing but unfinished service still blocks deletion' do
    admin = User.create!(email: "admin-#{SecureRandom.hex(4)}@example.com", role: 'platform_admin', password: 'Test-password-123')
    sign_in admin
    get admin_establishments_path
    assert_select "form[action='#{admin_establishment_path(@venue)}'][data-turbo-confirm]"
    get edit_admin_establishment_path(@venue)
    assert_select 'input[name="confirmation"]', count: 0
    order = build_order(@table, @product)
    delete admin_establishment_path(@venue)
    assert_nil @venue.reload.deleted_at
    order.order_items.update_all(status: 'denied')
    order.update!(status: 'denied')
    delete admin_establishment_path(@venue)
    assert @venue.reload.deleted_at
    assert_not @manager.reload.active?
  end

  test 'upgrade preserves existing division permission without enabling new venues' do
    @venue.update_columns(service_division_enabled: true, production_areas_limit: 0)
    3.times { |i| @venue.production_areas.create!(name: "Área #{i + 1}") }
    other, = build_venue
    require Rails.root.join('db/migrate/20261009180000_preserve_existing_service_area_permissions')
    PreserveExistingServiceAreaPermissions.new.up
    assert_equal 3, @venue.reload.production_areas_limit
    assert_equal 3, @venue.available_production_areas.count
    assert_equal 0, other.reload.production_areas_limit
    assert_not other.production_areas_enabled?
  end
end
