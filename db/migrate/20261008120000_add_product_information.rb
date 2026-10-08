class AddProductInformation < ActiveRecord::Migration[7.1]
  def change
    add_column :menu_items, :allergens, :jsonb, null: false, default: []
    add_column :menu_items, :allergen_notes, :string, limit: 500
    add_column :menu_items, :nutrition_enabled, :boolean, null: false, default: false
    add_column :menu_items, :nutrition_basis, :string, null: false, default: '100g'
    add_column :menu_items, :nutrition_portion, :string, limit: 100
    %i[energy fat saturated carbs sugar protein fibre salt].each do |field|
      add_column :menu_items, "nutrition_#{field}", :decimal, precision: 8, scale: 2
    end
  end
end
