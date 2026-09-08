class AddMenuItemDescriptionsAndOrderPayments < ActiveRecord::Migration[7.1]
  def change
    add_column :menu_items, :description, :text

    add_column :orders, :paid_at, :datetime
    add_reference :orders, :paid_by_user, foreign_key: { to_table: :users }
    add_index :orders, [:table_id, :paid_at]
  end
end
