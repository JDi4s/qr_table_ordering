class RememberExplicitMenuGroups < ActiveRecord::Migration[7.1]
  def change
    add_column :lunch_menus, :groups_configured, :boolean, default: false, null: false
  end
end
