class CreateStaffPushSubscriptions < ActiveRecord::Migration[7.1]
  def change
    create_table :staff_push_subscriptions do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.text :endpoint, null: false
      t.text :p256dh, null: false
      t.text :auth, null: false
      t.timestamps
    end

    add_index :staff_push_subscriptions, :user_id, unique: true
    add_index :staff_push_subscriptions, :endpoint, unique: true
  end
end
