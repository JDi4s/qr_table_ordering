class AllowMultipleStaffPushSubscriptions < ActiveRecord::Migration[7.1]
  def up
    remove_index :staff_push_subscriptions, :user_id
    add_index :staff_push_subscriptions, :user_id
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'Vários dispositivos por utilizador não podem ser reduzidos sem eliminar subscrições.'
  end
end
