class AddUniqueIndexesToTables < ActiveRecord::Migration[7.1]
  def change
    add_index :tables, :number, unique: true unless index_exists?(:tables, :number)
    add_index :tables, :qr_token, unique: true unless index_exists?(:tables, :qr_token)
  end
end
