require 'test_helper'

class ServiceOrganizationIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @venue, @table, @product = build_venue
    @manager = venue_user(@venue)
    @kitchen = @venue.production_areas.create!(name: 'Cozinha principal', preparation_key: 'kitchen')
    @counter = @venue.production_areas.create!(name: 'Balcão 2', preparation_key: 'counter')
    @venue.update!(service_division_enabled: true)
    @zone = @venue.service_zones.create!(name: 'Primeiro andar', routing: { 'kitchen' => @kitchen.id, 'counter' => @counter.id })
    @table.update!(service_zone: @zone)
    @product.update!(product_kind: 'plate', preparation_key: 'kitchen')
    @drink = @product.category.menu_items.create!(name: 'Água', price: 1, product_kind: 'drink', preparation_key: 'counter')
  end

  test 'accepted order routes components and preparation account sees only authorized work' do
    order = @table.orders.create!(customer_token: 'a', status: 'pending', total: 11) do |o|
      o.order_items.build(menu_item: @product, quantity: 1, unit_price: 10)
      o.order_items.build(menu_item: @drink, quantity: 1, unit_price: 1)
    end
    assert_no_difference('PreparationTask.count') { assert order.pending? }
    order.finalize_review!
    assert_equal [@kitchen.id, @counter.id].sort, order.preparation_tasks.pluck(:production_area_id).sort
    cook = venue_user(@venue, role: 'staff')
    cook.update!(service_role: 'preparation')
    cook.production_areas << @kitchen
    sign_in cook
    get staff_preparations_path
    assert_response :success
    assert_select '.preparation-line', count: 1
    assert_select '.preparation-line', text: /#{@product.name}/
    kitchen_task = order.preparation_tasks.find_by!(production_area: @kitchen)
    counter_task = order.preparation_tasks.find_by!(production_area: @counter)
    patch staff_preparation_path(counter_task), params: { state: 'ready' }
    assert_response :forbidden
    patch staff_preparation_path(kitchen_task), params: { state: 'ready' }
    assert_equal 'ready', kitchen_task.reload.state
    assert_equal 'accepted', order.reload.status
    patch staff_preparation_path(kitchen_task), params: { state: 'delivered' }
    assert_equal 'ready', kitchen_task.reload.state
    get staff_reports_path
    assert_redirected_to staff_preparations_path
    sign_in @manager
    patch staff_preparation_path(counter_task), params: { state: 'ready' }
    patch staff_preparation_path(kitchen_task), params: { state: 'delivered' }
    assert order.reload.accepted?
    patch staff_preparation_path(counter_task), params: { state: 'delivered' }
    assert order.reload.served?
    patch staff_preparation_path(counter_task), params: { state: 'delivered' }
    assert order.reload.served?
  end

  test 'classification applies only selected venue products and rejects foreign routing' do
    foreign, _, foreign_product = build_venue
    foreign_area = foreign.production_areas.create!(name: 'Outra cozinha')
    sign_in @manager
    patch staff_product_classification_path, params: { product_ids: [@product.id], classification: { normal_menu_visible: '0', product_kind: 'soup' } }
    assert_not @product.reload.normal_menu_visible?
    assert_equal 'soup', @product.product_kind
    assert @drink.reload.normal_menu_visible?
    patch staff_product_classification_path, params: { product_ids: [foreign_product.id], classification: { normal_menu_visible: '0' } }
    assert foreign_product.reload.normal_menu_visible?
    assert_not @zone.update(routing: { 'kitchen' => foreign_area.id })
    assert_not @table.update(service_zone: foreign.service_zones.create!(name: 'Outra zona'))
  end

  test 'admin deletion requires explicit identifier and preserves history while blocking accounts' do
    admin = User.create!(email: "admin-#{SecureRandom.hex(3)}@example.com", role: 'platform_admin', password: 'Test-password-123')
    sign_in admin
    delete admin_establishment_path(@venue), params: { confirmation: 'wrong' }
    assert_nil @venue.reload.deleted_at
    delete admin_establishment_path(@venue), params: { confirmation: @venue.slug }
    assert @venue.reload.deleted_at
    assert_not @venue.active?
    assert_not @manager.reload.venue_access?
    assert @table.reload.id
    get admin_establishments_path
    assert_select '.admin-client-card h2', text: @venue.name, count: 0
    patch admin_establishment_path(@venue), params: { establishment: { active: '1' } }
    assert_response :not_found
  end
end
