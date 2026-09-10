class CreatePaymentsAndAuditEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :payments do |t|
      t.references :order, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :payment_method, null: false, default: 'cash'
      t.decimal :amount, precision: 10, scale: 2, null: false, default: 0
      t.datetime :paid_at, null: false
      t.timestamps
    end
    add_index :payments, [:order_id, :paid_at]
    add_check_constraint :payments, "payment_method IN ('cash', 'card', 'mbway', 'other')", name: 'valid_payment_method'

    create_table :payment_items do |t|
      t.references :payment, null: false, foreign_key: true
      t.references :order_item, null: false, foreign_key: true
      t.integer :quantity, null: false
      t.decimal :unit_price, precision: 10, scale: 2, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.timestamps
    end

    create_table :audit_events do |t|
      t.references :establishment, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.references :auditable, polymorphic: true, index: true
      t.string :action, null: false
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :audit_events, [:establishment_id, :created_at]
  end
end
