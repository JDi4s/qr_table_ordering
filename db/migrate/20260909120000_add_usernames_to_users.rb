class AddUsernamesToUsers < ActiveRecord::Migration[7.1]
  def up
    add_column :users, :username, :string unless column_exists?(:users, :username)

    execute <<~SQL
      UPDATE users
      SET username = COALESCE(NULLIF(regexp_replace(lower(split_part(email, '@', 1)), '[^a-z0-9]+', '_', 'g'), ''), 'utilizador') || '_' || id::text
      WHERE username IS NULL
    SQL

    add_index :users, 'lower(username)', unique: true, name: 'index_users_on_lower_username' unless index_exists?(:users, 'lower(username)', name: 'index_users_on_lower_username')
  end

  def down
    remove_index :users, name: 'index_users_on_lower_username' if index_exists?(:users, 'lower(username)', name: 'index_users_on_lower_username')
    remove_column :users, :username if column_exists?(:users, :username)
  end
end
