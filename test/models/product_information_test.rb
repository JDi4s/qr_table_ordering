require 'test_helper'

class ProductInformationTest < ActiveSupport::TestCase
  setup { @venue, @table, @item = build_venue }

  test 'existing products need no optional information and blank nutrition is not presented as zero' do
    assert @item.valid?
    assert_not @item.product_information?
    @item.update!(nutrition_enabled: true, nutrition_energy: 0, nutrition_fat: nil)
    assert_equal [['Energia', 0, 'kcal']], @item.nutrition_rows
    @item.update!(nutrition_enabled: false)
    assert_empty @item.nutrition_rows
    assert_not @item.product_information?
  end

  test 'allergens are normalized and invalid choices or negative nutrition are rejected' do
    @item.update!(allergens: ['', 'milk', 'gluten', 'milk'], allergen_notes: '  Pode conter soja  ')
    assert_equal %w[milk gluten], @item.allergens
    assert_equal ['Glúten', 'Leite'], @item.allergen_labels
    assert_equal 'Pode conter soja', @item.allergen_notes
    assert_not @item.update(allergens: ['invented'])
    assert_not @item.update(allergens: { 'milk' => true })
    @item.allergens = []
    assert_not @item.update(nutrition_energy: -1)
    assert_not @item.update(nutrition_energy: 'invalid')
    assert_not @item.update(nutrition_energy: 100000)
  end

  test 'portion basis requires its label and disabling nutrition preserves saved values' do
    assert_not @item.update(nutrition_enabled: true, nutrition_basis: 'portion')
    @item.update!(nutrition_portion: '1 croissant · 120 g', nutrition_protein: 10.5)
    assert_equal 'Por porção · 1 croissant · 120 g', @item.nutrition_basis_label
    assert_equal [['Proteínas', 10.5, 'g']], @item.nutrition_rows
    @item.update!(nutrition_enabled: false)
    assert_equal 10.5, @item.reload.nutrition_protein
    assert_empty @item.nutrition_rows
  end
end
