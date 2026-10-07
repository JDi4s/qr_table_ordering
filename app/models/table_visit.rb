class TableVisit < ApplicationRecord
  belongs_to :table
  has_many :orders, dependent: :restrict_with_error
  after_commit :broadcast_status, on: [:create, :update]

  def open?
    opened_at.present? && closed_at.nil?
  end

  def waiting?
    requested_at.present? && opened_at.nil? && closed_at.nil?
  end

  def state
    return 'closed' if closed_at?
    open? ? 'open' : 'waiting'
  end

  def self.request_for!(table)
    with_table_lock(table) do
      visit = where(table: table, closed_at: nil).first
      visit ||= create!(table: table, requested_at: Time.current)
      visit
    end
  end

  def self.activate_for!(table)
    with_table_lock(table) do
      visit = where(table: table, closed_at: nil).first || new(table: table)
      visit.update!(opened_at: Time.current) unless visit.open?
      visit
    end
  end

  def self.close_for!(table)
    with_table_lock(table, require_available: false) do
      raise Order::InvalidTransition, 'Existem pedidos por concluir ou pagar nesta mesa.' if table.orders.unpaid.exists?
      visit = where(table: table, closed_at: nil).first
      visit&.update!(closed_at: Time.current)
      visit
    end
  end

  def self.close_if_settled!(table)
    close_for!(table) unless table.orders.unpaid.exists?
  end

  def self.with_table_lock(table, require_available: true, &block)
    table.establishment.with_lock do
      table.with_lock do
        if require_available && !(table.active? && !table.deleted? && table.establishment.active?)
          raise Order::InvalidTransition, 'Esta mesa está desativada.'
        end
        block.call
      end
    end
  end

  private

  def broadcast_status
    payload = { table_id: table_id, visit_id: id, state: state,
                requested_at: requested_at&.iso8601, table_number: table.number }
    ActionCable.server.broadcast("table_access_#{table_id}", payload)
    ActionCable.server.broadcast("table_activation_#{table.establishment_id}", payload)
    if waiting? && previous_changes.key?('id')
      StaffPushNotifier.notify_table_activation(self)
    end
  end
end
