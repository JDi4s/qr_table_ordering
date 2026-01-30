class AddCustomerTokenToOrders < ActiveRecord::Migration[7.1]
  def change
    add_column :orders, :customer_token, :string
    add_index :orders, :customer_token
  end
end
