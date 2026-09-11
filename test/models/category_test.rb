require 'test_helper'

class CategoryTest < ActiveSupport::TestCase
  test 'detects products used by an ongoing order' do
    venue, table, product = build_venue
    category = product.category
    order = build_order(table, product)

    assert category.used_by_ongoing_order?

    order.update!(status: 'denied')
    assert_not category.used_by_ongoing_order?
  end

  test 'recognises the reserved uncategorized category' do
    category = Category.new(name: '  sem CATEGORIA ')

    assert category.uncategorized?
  end
end
