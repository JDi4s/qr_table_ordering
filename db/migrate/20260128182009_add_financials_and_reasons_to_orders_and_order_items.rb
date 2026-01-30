class AddFinancialsAndReasonsToOrdersAndOrderItems < ActiveRecord::Migration[7.1]
  def change
    add_column :order_items, :unit_price, :decimal, precision: 10, scale: 2, null: false, default: 0
    add_column :order_items, :denial_reason, :string

    add_column :orders, :total, :decimal, precision: 10, scale: 2, null: false, default: 0

    add_index :order_items, :status
  end
end
