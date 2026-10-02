class CreateLandingRequests < ActiveRecord::Migration[7.1]
  def change
    create_table :landing_requests do |t|
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :business_email, null: false
      t.string :phone, null: false
      t.string :region, null: false
      t.string :business_type, null: false
      t.string :status, null: false, default: 'new'
      t.timestamps
    end

    add_index :landing_requests, [:status, :created_at]
  end
end
