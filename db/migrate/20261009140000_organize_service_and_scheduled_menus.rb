class OrganizeServiceAndScheduledMenus < ActiveRecord::Migration[7.1]
  def change
    add_column :menu_items, :product_kind, :string, null: false, default: 'unclassified'
    add_column :menu_items, :normal_menu_visible, :boolean, null: false, default: true
    add_column :menu_items, :preparation_key, :string, null: false, default: 'counter'
    add_column :lunch_menus, :menu_kind, :string, null: false, default: 'lunch'
    add_column :lunch_menus, :title, :string
    add_column :lunch_menus, :group_definitions, :jsonb, null: false, default: []
    remove_index :lunch_menus, :establishment_id
    add_index :lunch_menus, [:establishment_id, :menu_kind], unique: true
    add_column :establishments, :deleted_at, :datetime
    add_column :establishments, :service_division_enabled, :boolean, null: false, default: false
    add_column :production_areas, :preparation_key, :string, null: false, default: 'counter'
    reversible { |dir| dir.up { execute "UPDATE production_areas SET preparation_key = 'kitchen' WHERE name = 'Cozinha'" } }
    create_table :service_zones do |t|
      t.references :establishment, null: false, foreign_key: true
      t.string :name, null: false
      t.jsonb :routing, null: false, default: {}
      t.timestamps
    end
    add_index :service_zones, [:establishment_id, :name], unique: true
    add_reference :tables, :service_zone, foreign_key: true
    add_column :users, :service_role, :string, null: false, default: 'floor'
    create_table :preparation_tasks do |t|
      t.references :order_item, null: false, foreign_key: true
      t.references :production_area, foreign_key: true
      t.string :name, null: false
      t.string :component_key, null: false
      t.string :state, null: false, default: 'preparing'
      t.integer :quantity, null: false
      t.datetime :ready_at
      t.datetime :delivered_at
      t.references :updated_by, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :preparation_tasks, [:order_item_id, :component_key], unique: true
  end
end
