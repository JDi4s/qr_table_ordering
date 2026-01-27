class CreateTables < ActiveRecord::Migration[7.0]
  def change
    create_table :tables do |t|
      t.integer :number
      t.string :qr_token, null: false, unique: true

      t.timestamps
    end
    add_index :tables, :qr_token, unique: true
  end
end
