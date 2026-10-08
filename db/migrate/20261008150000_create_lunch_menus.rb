class CreateLunchMenus < ActiveRecord::Migration[7.1]
  def change
    create_table :lunch_menus do |t|
      t.references :establishment, null: false, foreign_key: true, index: { unique: true }
      t.boolean :active, null: false, default: false
      t.jsonb :weekdays, null: false, default: [1, 2, 3, 4, 5]
      t.time :starts_at, null: false, default: '12:00'
      t.time :ends_at, null: false, default: '15:00'
      t.boolean :individual_enabled, null: false, default: true
      t.boolean :combo_enabled, null: false, default: false
      t.decimal :combo_price, precision: 8, scale: 2, null: false, default: 12
      t.jsonb :individual_offers, null: false, default: []
      t.jsonb :combo_groups, null: false, default: {}
      t.timestamps
    end
    add_column :order_items, :lunch_selection, :jsonb, null: false, default: {}
  end
end
