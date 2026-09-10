class AddCancellationFieldsToOrders < ActiveRecord::Migration[7.1]
  def change
    add_column :orders, :cancelled_at, :datetime
    add_column :orders, :cancellation_reason, :string
    add_index :orders, :cancelled_at
  end
end
