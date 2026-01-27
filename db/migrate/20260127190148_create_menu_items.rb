class CreateMenuItems < ActiveRecord::Migration[7.1]
  def change
    create_table :menu_items do |t|
      t.string :name
      t.decimal :price
      t.boolean :available
      t.references :category, null: false, foreign_key: true

      t.timestamps
    end
  end
end
