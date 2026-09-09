class CreateMenuItemRecommendations < ActiveRecord::Migration[7.1]
  def change
    create_table :menu_item_recommendations do |t|
      t.references :menu_item, null: false, foreign_key: true
      t.references :recommended_menu_item, null: false, foreign_key: { to_table: :menu_items }
      t.timestamps
    end

    add_index :menu_item_recommendations, [:menu_item_id, :recommended_menu_item_id],
              unique: true, name: 'unique_menu_item_recommendation'
    add_check_constraint :menu_item_recommendations,
                         'menu_item_id <> recommended_menu_item_id',
                         name: 'recommendation_cannot_reference_itself'
  end
end
