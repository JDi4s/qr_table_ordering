require 'test_helper'
class ScheduledMenuTest < ActiveSupport::TestCase
  test 'breakfast is independent of lunch and hidden products remain available through its signed menu' do
    venue, _, product = build_venue
    product.update!(product_kind: 'snack', normal_menu_visible: false)
    coffee = product.category.menu_items.create!(name: 'Café', product_kind: 'coffee', price: 1)
    breakfast = venue.scheduled_menus.create!(menu_kind: 'breakfast', starts_at: '08:00', ends_at: '11:00', combo_price: 4, combo_enabled: true, active: true,
      individual_offers: [{ 'menu_item_id' => product.id, 'price' => '2' }],
      combo_groups: { 'coffee' => [{ 'menu_item_id' => coffee.id, 'supplement' => '0' }], 'bread' => [{ 'menu_item_id' => product.id, 'supplement' => '0' }], 'drink' => [] })
    venue.create_lunch_menu!(active: false)
    assert_equal 2, venue.scheduled_menus.count
    assert_equal 'lunch', venue.reload.lunch_menu.menu_kind
    travel_to Time.zone.local(2026,10,9,9,0) do
      assert breakfast.open?
      assert_equal product, breakfast.available_individual_offers.first[:item]
      row = breakfast.selection(kind: 'combo', quantity: 1, choices: { 'coffee' => coffee.id, 'bread' => product.id })
      assert_equal 4, row[:unit_price]
      assert_equal row, LunchMenu.validated_selection(venue,row[:lunch_selection],nil,1,'4')
    end
    travel_to Time.zone.local(2026,10,9,12,0) { assert_not breakfast.open? }
    assert_equal ['Pequeno-almoço'], product.menu_labels
  end
  test 'typed groups exclude unrelated products and enforce validation' do
    venue, _, soup = build_venue
    soup.update!(product_kind: 'soup')
    juice = soup.category.menu_items.create!(name: 'Sumo', price: 1, product_kind: 'drink')
    menu = venue.create_lunch_menu!(group_definitions: [{ 'key' => 'soup', 'name' => 'Sopa', 'types' => ['soup'], 'optional' => false }],
      combo_groups: { 'soup' => [{ 'menu_item_id' => soup.id, 'supplement' => '0' }] })
    assert_equal [soup.id], menu.available_groups.first[:options].map { |o| o[:id] }
    assert_not menu.update(combo_groups: { 'soup' => [{ 'menu_item_id' => juice.id, 'supplement' => '0' }] })
  end
end
