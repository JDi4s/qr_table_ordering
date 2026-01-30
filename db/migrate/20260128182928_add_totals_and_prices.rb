class AddTotalsAndPrices < ActiveRecord::Migration[7.1]
  def change
    add_column :orders, :total, :decimal, precision: 10, scale: 2, null: false, default: 0 unless column_exists?(:orders, :total)

    add_column :order_items, :unit_price, :decimal, precision: 10, scale: 2, null: false, default: 0 unless column_exists?(:order_items, :unit_price)
    add_column :order_items, :denial_reason, :string unless column_exists?(:order_items, :denial_reason)
  end
end
