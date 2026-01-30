class AddDenialReasonToOrders < ActiveRecord::Migration[7.1]
  def change
    unless column_exists?(:orders, :denial_reason)
      add_column :orders, :denial_reason, :string
    end
  end
end
