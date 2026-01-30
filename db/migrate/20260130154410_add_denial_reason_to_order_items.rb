class AddDenialReasonToOrderItems < ActiveRecord::Migration[7.1]
  def change
    unless column_exists?(:order_items, :denial_reason)
      add_column :order_items, :denial_reason, :string
    end
  end
end
