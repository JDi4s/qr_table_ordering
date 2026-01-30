class AddServedAtToOrders < ActiveRecord::Migration[7.1]
  def change
    unless column_exists?(:orders, :served_at)
      add_column :orders, :served_at, :datetime
    end
  end
end
