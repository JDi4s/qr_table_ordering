require 'test_helper'

class ProductInformationIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @venue, @table, @item = build_venue
    @manager = venue_user(@venue)
  end

  test 'manager saves edits and clears optional fields while another establishment cannot edit them' do
    sign_in(@manager)
    post staff_menu_items_path, params: { menu_item: {
      name: 'Croissant misto', price: 3.5, category_id: @item.category_id, description: 'Queijo e fiambre',
      allergens: ['', 'milk', 'gluten'], allergen_notes: 'Pode conter ovos', nutrition_enabled: '1',
      nutrition_basis: '100g', nutrition_energy: '312', nutrition_protein: '10', nutrition_salt: ''
    } }
    assert_response :see_other
    created = @venue.menu_items.find_by!(name: 'Croissant misto')
    assert_equal %w[milk gluten], created.allergens
    assert_equal 312, created.nutrition_energy
    assert_nil created.nutrition_salt
    get edit_staff_menu_item_path(created)
    assert_select 'input[name="menu_item[allergens][]"][value="milk"][checked]'
    assert_select '#menu_item_nutrition_enabled[checked]'
    patch staff_menu_item_path(created), params: { menu_item: { category_id: created.category_id, allergens: [''], allergen_notes: '', nutrition_enabled: '0' } }
    assert_empty created.reload.allergens
    assert_empty created.nutrition_rows
    other, = build_venue
    sign_in(venue_user(other))
    patch staff_menu_item_path(created), params: { menu_item: { category_id: created.category_id, description: 'Changed' } }
    assert_response :not_found
    assert_equal 'Queijo e fiambre', created.reload.description
  end

  test 'customer information is escaped optional and scoped to visible menu products' do
    @item.update!(description: '<script>alert(1)</script>', allergens: ['milk'], nutrition_enabled: true, nutrition_energy: 312)
    @item.category.menu_items.create!(name: 'Sem detalhes', price: 1)
    get new_table_order_path(@table)
    assert_select '.customer-product-info-button', count: 2
    assert_select 'template .product-info-description', text: '<script>alert(1)</script>'
    assert_select 'template script', count: 0
    assert_select 'template .product-info-pills span', text: 'Leite'
    assert_select 'template .product-info-nutrition-grid > div', count: 1
    assert_select 'template', count: 2
    assert_select 'template button', count: 2
    assert_select 'template .product-info-title h2', text: 'Sem detalhes'
    assert_select 'template .product-info-close'
    @item.update!(nutrition_enabled: false)
    get new_table_order_path(@table)
    assert_select 'template .product-info-nutrition', count: 0
  end
end
