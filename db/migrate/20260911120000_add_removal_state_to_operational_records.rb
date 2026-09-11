class AddRemovalStateToOperationalRecords < ActiveRecord::Migration[7.1]
  def up
    add_column :users, :deleted_at, :datetime
    add_column :tables, :deleted_at, :datetime
    add_column :orders, :voided_at, :datetime
    add_reference :orders, :voided_by_user, foreign_key: { to_table: :users }

    add_index :users, :deleted_at
    add_index :tables, :deleted_at
    add_index :orders, :voided_at

    remove_index :users, name: 'index_users_on_lower_username'
    add_index :users, 'lower(username)', unique: true, where: 'deleted_at IS NULL',
              name: 'index_users_on_lower_username'

    remove_index :tables, name: 'index_tables_on_establishment_id_and_number'
    add_index :tables, [:establishment_id, :number], unique: true, where: 'deleted_at IS NULL',
              name: 'index_tables_on_establishment_id_and_number'
  end

  def down
    remove_index :tables, name: 'index_tables_on_establishment_id_and_number'
    add_index :tables, [:establishment_id, :number], unique: true,
              name: 'index_tables_on_establishment_id_and_number'

    remove_index :users, name: 'index_users_on_lower_username'
    add_index :users, 'lower(username)', unique: true, name: 'index_users_on_lower_username'

    remove_reference :orders, :voided_by_user, foreign_key: { to_table: :users }
    remove_column :orders, :voided_at
    remove_column :tables, :deleted_at
    remove_column :users, :deleted_at
  end
end
