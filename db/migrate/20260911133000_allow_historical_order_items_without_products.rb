class AllowHistoricalOrderItemsWithoutProducts < ActiveRecord::Migration[7.1]
  def up
    change_column_null :order_items, :menu_item_id, true
    remove_foreign_key :order_items, :menu_items
    add_foreign_key :order_items, :menu_items, on_delete: :nullify
  end

  def down
    if connection.select_value('SELECT EXISTS (SELECT 1 FROM order_items WHERE menu_item_id IS NULL)')
      raise ActiveRecord::IrreversibleMigration, 'Não é possível restaurar produtos já eliminados.'
    end

    remove_foreign_key :order_items, :menu_items
    add_foreign_key :order_items, :menu_items
    change_column_null :order_items, :menu_item_id, false
  end
end
