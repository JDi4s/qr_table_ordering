class AddSupportAndCommercialPlans < ActiveRecord::Migration[7.1]
  def change
    add_column :establishments, :plan, :string, null: false, default: 'essential'
    add_check_constraint :establishments, "plan IN ('essential', 'management')", name: 'valid_establishment_plan'

    reversible do |direction|
      direction.up { execute "UPDATE establishments SET plan = 'management'" }
    end

    create_table :support_tickets do |t|
      t.references :establishment, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.references :assigned_to, foreign_key: { to_table: :users }
      t.string :subject, null: false
      t.string :category, null: false, default: 'other'
      t.string :priority, null: false, default: 'normal'
      t.string :status, null: false, default: 'open'
      t.timestamps
    end
    add_index :support_tickets, [:establishment_id, :status]
    add_check_constraint :support_tickets, "status IN ('open', 'in_analysis', 'waiting_establishment', 'resolved')", name: 'valid_support_ticket_status'
    add_check_constraint :support_tickets, "priority IN ('normal', 'urgent')", name: 'valid_support_ticket_priority'

    create_table :support_ticket_messages do |t|
      t.references :support_ticket, null: false, foreign_key: true
      t.references :author, null: false, foreign_key: { to_table: :users }
      t.text :body
      t.timestamps
    end

    create_table :support_sessions do |t|
      t.references :platform_admin, null: false, foreign_key: { to_table: :users }
      t.references :establishment, null: false, foreign_key: true
      t.references :support_ticket, foreign_key: true
      t.text :reason
      t.datetime :started_at, null: false
      t.datetime :expires_at, null: false
      t.datetime :ended_at
      t.timestamps
    end
    add_index :support_sessions, [:platform_admin_id, :ended_at]
  end
end
