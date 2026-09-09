class AddArchivedAtToMenuStructure < ActiveRecord::Migration[7.1]
  def change
    add_column :categories, :archived_at, :datetime
    add_column :menu_items, :archived_at, :datetime

    add_index :categories, :archived_at
    add_index :menu_items, :archived_at
  end
end
