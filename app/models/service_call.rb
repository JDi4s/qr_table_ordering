class ServiceCall < ApplicationRecord
  include ActionView::RecordIdentifier
  belongs_to :table
  belongs_to :assigned_user, class_name: 'User', optional: true
  enum status: { pending: 'pending', claimed: 'claimed', resolved: 'resolved' }
  after_create_commit :broadcast_created
  after_update_commit :broadcast_updated

  def self.request_for!(table)
    table.with_lock do
      raise Order::InvalidTransition, 'Mesa indisponível.' unless table.active? && table.establishment.reload.active?
      existing = table.service_calls.where(status: %w[pending claimed]).first
      return existing if existing
      if table.service_calls.where('created_at > ?', 60.seconds.ago).exists?
        raise Order::InvalidTransition, 'Aguarde um minuto antes de voltar a chamar.'
      end
      table.service_calls.create!
    end
  end

  def progress!(user, decision)
    with_lock do
      raise Order::InvalidTransition, 'Chamada indisponível.' unless user.venue_access? && user.establishment_id == table.establishment_id
      if decision == 'claimed' && pending?
        update!(status: 'claimed', assigned_user: user)
      elsif decision == 'resolved' && claimed? && (assigned_user_id == user.id || user.manager?)
        update!(status: 'resolved', resolved_at: Time.current)
      else
        raise Order::InvalidTransition, 'A chamada já foi assumida ou atendida. Atualize a página.'
      end
    end
  end

  private

  def broadcast_created
    broadcast_append_to(table.establishment.staff_stream, target: 'service_calls', partial: 'staff/service_calls/call', locals: { service_call: self })
  end

  def broadcast_updated
    if resolved?
      broadcast_remove_to(table.establishment.staff_stream, target: dom_id(self))
    else
      broadcast_replace_to(table.establishment.staff_stream, target: dom_id(self), partial: 'staff/service_calls/call', locals: { service_call: self })
    end
  end
end
