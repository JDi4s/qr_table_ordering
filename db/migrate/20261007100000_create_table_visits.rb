class CreateTableVisits < ActiveRecord::Migration[7.1]
  def up
    create_table :table_visits do |t|
      t.references :table, null: false, foreign_key: true
      t.datetime :requested_at
      t.datetime :opened_at
      t.datetime :closed_at
      t.timestamps
    end
    add_index :table_visits, :table_id, unique: true, where: 'closed_at IS NULL', name: 'one_current_visit_per_table'
    add_reference :orders, :table_visit, foreign_key: true

    # Keep existing service running when this release is installed.
    execute <<~SQL
      INSERT INTO table_visits (table_id, opened_at, created_at, updated_at)
      SELECT DISTINCT tables.id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM tables INNER JOIN orders ON orders.table_id = tables.id
      WHERE tables.active = TRUE AND tables.deleted_at IS NULL
        AND orders.voided_at IS NULL AND orders.paid_at IS NULL AND orders.status <> 'denied';
      UPDATE orders SET table_visit_id = table_visits.id
      FROM table_visits WHERE orders.table_id = table_visits.table_id
        AND orders.voided_at IS NULL AND orders.paid_at IS NULL AND orders.status <> 'denied';
    SQL
  end

  def down
    remove_reference :orders, :table_visit, foreign_key: true
    drop_table :table_visits
  end
end
