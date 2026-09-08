class AddPaidQuantityToOrderItems < ActiveRecord::Migration[7.1]
  def change
    add_column :order_items, :paid_quantity, :integer, default: 0, null: false
    add_index :order_items, :paid_quantity
  end
end
