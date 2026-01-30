class AddStaffSoundEnabledToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :staff_sound_enabled, :boolean, null: false, default: true
  end
end
