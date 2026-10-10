class AddScheduledMenuMembership < ActiveRecord::Migration[7.1]
  def up
    add_column :menu_items, :scheduled_menu_visible, :boolean, default: false, null: false
    execute 'UPDATE menu_items SET scheduled_menu_visible = TRUE WHERE normal_menu_visible = FALSE'
    menus = Class.new(ActiveRecord::Base) { self.table_name = 'lunch_menus' }
    items = Class.new(ActiveRecord::Base) { self.table_name = 'menu_items' }
    menus.find_each do |menu|
      ids = (menu.individual_offers + menu.combo_groups.values.flatten).map { |row| row['menu_item_id'].to_i }
      items.where(id: ids, category_id: Category.where(establishment_id: menu.establishment_id).select(:id)).update_all(scheduled_menu_visible: true)
    end
  end
  def down
    remove_column :menu_items, :scheduled_menu_visible
  end
end
