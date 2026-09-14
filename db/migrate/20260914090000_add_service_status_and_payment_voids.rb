class AddServiceStatusAndPaymentVoids < ActiveRecord::Migration[7.1]
  def change
    add_column :establishments, :accepting_orders, :boolean, null: false, default: true
    add_column :establishments, :service_paused_at, :datetime
    add_reference :establishments, :service_paused_by_user, foreign_key: { to_table: :users }

    add_column :payments, :voided_at, :datetime
    add_reference :payments, :voided_by_user, foreign_key: { to_table: :users }
    add_column :payments, :void_reason, :string
    add_index :payments, :voided_at

    add_column :cash_closures, :reopened_at, :datetime
    add_reference :cash_closures, :reopened_by_user, foreign_key: { to_table: :users }
    add_column :cash_closures, :reopen_reason, :string
    remove_index :cash_closures, [:establishment_id, :business_date]
    add_index :cash_closures, [:establishment_id, :business_date], unique: true,
      where: 'reopened_at IS NULL', name: 'one_active_cash_closure_per_day'
  end
end
