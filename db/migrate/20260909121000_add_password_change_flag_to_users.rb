class AddPasswordChangeFlagToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :must_change_password, :boolean, null: false, default: false unless column_exists?(:users, :must_change_password)
  end
end
