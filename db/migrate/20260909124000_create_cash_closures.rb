class CreateCashClosures < ActiveRecord::Migration[7.1]
  def change
    create_table :cash_closures do |t|
      t.references :establishment, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.date :business_date, null: false
      t.decimal :total_amount, precision: 10, scale: 2, null: false, default: 0
      t.integer :payments_count, null: false, default: 0
      t.jsonb :payment_breakdown, null: false, default: {}
      t.datetime :closed_at, null: false
      t.timestamps
    end
    add_index :cash_closures, [:establishment_id, :business_date], unique: true
  end
end
