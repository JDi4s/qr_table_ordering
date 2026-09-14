class AddServiceStatusAndPaymentVoids < ActiveRecord::Migration[7.1]
  def up
    add_column :establishments, :accepting_orders, :boolean, null: false, default: true unless column_exists?(:establishments, :accepting_orders)
    add_column :establishments, :service_paused_at, :datetime unless column_exists?(:establishments, :service_paused_at)
    add_user_reference(:establishments, :service_paused_by_user)

    add_column :payments, :voided_at, :datetime unless column_exists?(:payments, :voided_at)
    add_user_reference(:payments, :voided_by_user)
    add_column :payments, :void_reason, :string unless column_exists?(:payments, :void_reason)
    add_index :payments, :voided_at unless index_exists?(:payments, :voided_at)

    add_column :cash_closures, :reopened_at, :datetime unless column_exists?(:cash_closures, :reopened_at)
    add_user_reference(:cash_closures, :reopened_by_user)
    add_column :cash_closures, :reopen_reason, :string unless column_exists?(:cash_closures, :reopen_reason)

    old_index = 'index_cash_closures_on_establishment_id_and_business_date'
    remove_index :cash_closures, name: old_index if index_name_exists?(:cash_closures, old_index)
    unless index_name_exists?(:cash_closures, 'one_active_cash_closure_per_day')
      add_index :cash_closures, [:establishment_id, :business_date], unique: true,
        where: 'reopened_at IS NULL', name: 'one_active_cash_closure_per_day'
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'Some columns may have existed before this repair migration.'
  end

  private

  def add_user_reference(table, name)
    column = "#{name}_id"
    add_column table, column, :bigint unless column_exists?(table, column)
    add_index table, column unless index_exists?(table, column)
    add_foreign_key table, :users, column: column unless foreign_key_exists?(table, :users, column: column)
  end
end
