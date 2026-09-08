class AddEstablishmentsAndServiceCalls < ActiveRecord::Migration[7.1]
  def up
    create_table :establishments do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.integer :table_limit, null: false, default: 50
      t.integer :monthly_fee_cents, null: false, default: 10000
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :establishments, :slug, unique: true
    add_check_constraint :establishments, 'table_limit >= 0 AND monthly_fee_cents >= 0', name: 'establishment_limits_positive'
    legacy_id = connection.select_value(<<~SQL)
      INSERT INTO establishments (name, slug, table_limit, monthly_fee_cents, active, created_at, updated_at)
      VALUES ('Estabelecimento inicial', 'inicial', GREATEST(50, (SELECT COUNT(*) FROM tables)), 10000, TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      RETURNING id
    SQL
    [:tables, :categories, :users].each do |name|
      add_reference name, :establishment, foreign_key: true
      execute "UPDATE #{name} SET establishment_id = #{legacy_id}"
      change_column_null name, :establishment_id, false unless name == :users
    end
    add_column :users, :active, :boolean, null: false, default: true
    # Old admin accounts belong to the original venue, not to the platform owner.
    execute "UPDATE users SET role = 'manager' WHERE role = 'admin'"
    add_column :tables, :active, :boolean, null: false, default: true
    remove_index :tables, :number
    add_index :tables, [:establishment_id, :number], unique: true
    add_column :orders, :submission_token, :string
    add_index :orders, [:table_id, :customer_token, :submission_token], unique: true, name: 'unique_customer_submission'
    add_column :order_items, :name_snapshot, :string
    add_column :order_items, :proposed_description, :string
    add_column :order_items, :original_unit_price, :decimal, precision: 10, scale: 2
    execute 'UPDATE order_items SET original_unit_price = unit_price'
    execute "UPDATE orders SET customer_token = 'legacy-' || id::text WHERE customer_token IS NULL"
    execute 'UPDATE menu_items SET available = TRUE WHERE available IS NULL'
    change_column_default :menu_items, :available, true
    change_column_null :menu_items, :available, false
    execute 'UPDATE order_items SET name_snapshot = menu_items.name FROM menu_items WHERE menu_items.id = order_items.menu_item_id'
    create_table :service_calls do |t|
      t.references :table, null: false, foreign_key: true
      t.references :assigned_user, foreign_key: { to_table: :users }
      t.string :status, null: false, default: 'pending'
      t.datetime :resolved_at
      t.timestamps
    end
    add_index :service_calls, :table_id, unique: true, where: "status IN ('pending', 'claimed')", name: 'one_open_call_per_table'
    add_check_constraint :service_calls, "status IN ('pending', 'claimed', 'resolved')", name: 'valid_service_call_status'
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'Multi-establishment data must be restored from a backup.'
  end
end
