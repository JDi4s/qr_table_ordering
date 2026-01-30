class AddAvailabilityToCategories < ActiveRecord::Migration[7.1]
  def change
    add_column :categories, :available, :boolean, default: true, null: false
  end
end
