class AcceptOrdersWaitingForCustomerConfirmation < ActiveRecord::Migration[7.1]
  def up
    execute <<~SQL.squish
      UPDATE orders
      SET status = 'accepted', updated_at = CURRENT_TIMESTAMP
      WHERE status = 'needs_customer_action'
    SQL
  end

  def down
    # The previous state cannot be identified after these orders are accepted.
  end
end
