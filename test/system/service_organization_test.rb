require 'application_system_test_case'
class ServiceOrganizationSystemTest < ApplicationSystemTestCase
  test 'two simultaneous menus retain separate combinations and hidden products on a tablet' do
    venue, table, product = build_venue
    manager = venue_user(venue)
    bread = product.category.menu_items.create!(name: 'Croissant só de manhã', product_kind: 'snack', normal_menu_visible: false, price: 2)
    coffee = product.category.menu_items.create!(name: 'Café', product_kind: 'coffee', price: 1)
    soup = product.category.menu_items.create!(name: 'Sopa', product_kind: 'soup', price: 2)
    water = product.category.menu_items.create!(name: 'Água', product_kind: 'drink', price: 1)
    product.update!(product_kind: 'plate')
    venue.scheduled_menus.create!(menu_kind: 'breakfast', starts_at: '08:00', ends_at: '14:00', active: true, combo_enabled: true, combo_price: 5,
      individual_offers: [{ 'menu_item_id' => bread.id, 'price' => '2' }], combo_groups: {
        'coffee' => [{ 'menu_item_id' => coffee.id, 'supplement' => '0' }], 'bread' => [{ 'menu_item_id' => bread.id, 'supplement' => '0' }], 'drink' => [] })
    venue.create_lunch_menu!(active: true, individual_enabled: false, combo_enabled: true, combo_groups: {
      'soup' => [{ 'menu_item_id' => soup.id, 'supplement' => '0' }], 'plate' => [{ 'menu_item_id' => product.id, 'supplement' => '0' }],
      'drink' => [{ 'menu_item_id' => water.id, 'supplement' => '0' }], 'coffee' => [] })
    TableVisit.activate_for!(table)
    travel_to Time.zone.local(2026,10,9,13,0) do
      page.current_window.resize_to(1024,768)
      visit new_table_order_path(table)
      assert_button 'Pequeno-almoço'
      assert_button 'Almoço'
      within '#menu-root-breakfast' do
        assert_text bread.name
        click_button 'Escolher menu'
        click_button 'Adicionar menu'
      end
      assert_text '5,00 €'
      click_button 'Almoço'
      within '#menu-root-lunch' do
        click_button 'Escolher menu'
        click_button 'Adicionar menu'
      end
      assert_selector '.customer-cart-bar', text: '17,00 €'
      click_button 'Comida'
      assert_no_selector '.customer-product-card strong', text: bread.name
      assert page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')
      page.save_screenshot(Rails.root.join('tmp/screenshots/scheduled-tablet.png'))
      click_button 'Rever pedido'
      assert_text 'Pequeno-almoço'
      assert_text 'Menu completo'
    end
  end

  test 'kitchen tablet only shows assigned preparation and fits landscape portrait and mobile' do
    venue, table, food = build_venue
    venue.update!(service_division_enabled: true)
    kitchen = venue.production_areas.create!(name: 'Cozinha', preparation_key: 'kitchen')
    counter = venue.production_areas.create!(name: 'Balcão', preparation_key: 'counter')
    food.update!(name: 'Baguete', product_kind: 'snack', preparation_key: 'kitchen')
    drink = food.category.menu_items.create!(name: 'Sumo exclusivo do balcão', product_kind: 'drink', price: 1)
    cook = venue_user(venue, role: 'staff'); cook.update!(service_role: 'preparation'); cook.production_areas << kitchen
    order = table.orders.create!(customer_token: 'tablet-test', status: 'pending', total: 11) do |o|
      o.order_items.build(menu_item: food, quantity: 1, unit_price: 10)
      o.order_items.build(menu_item: drink, quantity: 1, unit_price: 1)
    end
    order.finalize_review!
    visit login_path
    fill_in 'Email', with: cook.email
    fill_in 'Palavra-passe', with: 'Test-password-123'
    click_button 'Entrar'
    assert_current_path staff_preparations_path
    [[1024,768],[768,1024],[390,844]].each do |width,height|
      page.current_window.resize_to(width,height)
      assert_text 'Baguete'
      assert_no_text drink.name
      assert page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')
      page.save_screenshot(Rails.root.join("tmp/screenshots/kitchen-#{width}.png"))
    end
    click_button '✓ Pronto'
    assert_text '✓ Pronto'
    assert_equal 'accepted', order.reload.status
  end
end
