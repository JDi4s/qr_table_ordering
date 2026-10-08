require 'test_helper'
class LunchMenuTest < ActiveSupport::TestCase
  setup do
    @venue, @table, @product = build_venue
    @menu = @venue.create_lunch_menu!(active: true, weekdays: (0..6).to_a, starts_at: '12:00', ends_at: '15:00',
      individual_offers: [{ 'menu_item_id' => @product.id, 'price' => '8.50' }], combo_enabled: true,
      combo_groups: LunchMenu::GROUPS.keys.to_h { |key| [key, [{ 'menu_item_id' => @product.id, 'supplement' => key == 'drink' ? '1.00' : '0' }]] })
  end
  test 'Lisbon schedule has inclusive start and exclusive end including summer time' do
    assert @menu.open?(at: Time.utc(2026, 10, 8, 11, 0))
    assert_not @menu.open?(at: Time.utc(2026, 10, 8, 14, 0))
    assert @menu.open?(at: Time.utc(2026, 12, 8, 12, 0))
    assert_equal Time.utc(2026, 10, 8, 14), @menu.next_transition_at(at: Time.utc(2026, 10, 8, 12))
  end
  test 'avulso and complete menus use server prices and snapshot choices' do
    travel_to Time.utc(2026, 10, 8, 12) do
      row = @menu.selection(kind: 'individual', quantity: 2, menu_item_id: @product.id)
      assert_equal BigDecimal('17'), row[:line_total]
      assert_equal BigDecimal('10'), @product.reload.price
      row = @menu.selection(kind: 'combo', quantity: 2, choices: %w[soup plate drink].to_h { |key| [key, @product.id] })
      assert_nil row[:menu_item_id]
      assert_equal BigDecimal('26'), row[:line_total]
      assert_equal 'Sem café', row[:lunch_selection]['choices'].last['name']
      assert_equal row, LunchMenu.validated_selection(@venue, row[:lunch_selection], nil, 2, '13')
      assert_raises(Order::InvalidTransition) { LunchMenu.validated_selection(@venue, row[:lunch_selection], nil, 2, '1') }
      @product.update!(available: false)
      assert_raises(Order::InvalidTransition) { LunchMenu.validated_selection(@venue.reload, row[:lunch_selection], nil, 2, '13') }
    end
  end
  test 'configuration rejects foreign products, negative supplements and imprecise prices' do
    _, _, foreign = build_venue
    @menu.individual_offers = [{ 'menu_item_id' => foreign.id, 'price' => '5' }]
    assert_not @menu.valid?
    @menu.individual_offers = [{ 'menu_item_id' => @product.id, 'price' => '-1' }]
    assert_not @menu.valid?
    @menu.individual_offers = [{ 'menu_item_id' => @product.id, 'price' => '1.001' }]
    assert_not @menu.valid?
  end
end
