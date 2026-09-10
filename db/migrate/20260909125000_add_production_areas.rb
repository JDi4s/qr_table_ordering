class AddProductionAreas < ActiveRecord::Migration[7.1]
  def change
    add_column :establishments, :production_areas_limit, :integer, null: false, default: 0
    add_check_constraint :establishments, 'production_areas_limit >= 0', name: 'production_areas_limit_positive'

    create_table :production_areas do |t|
      t.references :establishment, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :production_areas, [:establishment_id, :name], unique: true

    add_reference :menu_items, :production_area, foreign_key: true

    create_table :production_area_users, id: false do |t|
      t.references :production_area, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
    end
    add_index :production_area_users, [:production_area_id, :user_id], unique: true
  end
end
