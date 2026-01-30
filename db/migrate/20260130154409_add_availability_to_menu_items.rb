# db/migrate/20260130154409_add_availability_to_menu_items.rb  (FULL FILE — replace)
class AddAvailabilityToMenuItems < ActiveRecord::Migration[7.1]
  def change
    unless column_exists?(:menu_items, :available)
      add_column :menu_items, :available, :boolean, default: true, null: false
    end
  end
end
