class Payment < ApplicationRecord
  belongs_to :order
  belongs_to :user
  belongs_to :voided_by_user, class_name: 'User', optional: true
  has_many :payment_items, dependent: :destroy

  enum payment_method: { cash: 'cash', card: 'card', mbway: 'mbway', other: 'other' }
  scope :active, -> { where(voided_at: nil) }
  validates :amount, numericality: { greater_than: 0 }
  validates :paid_at, presence: true
  validates :payment_method, inclusion: { in: payment_methods.keys }
  validates :void_reason, presence: true, length: { maximum: 300 }, if: :voided?

  def voided?
    voided_at.present?
  end

  def void!(actor, reason:)
    reason = reason.to_s.strip
    raise Order::InvalidTransition, 'Indique o motivo da anulação.' if reason.blank?
    raise Order::InvalidTransition, 'O motivo não pode ultrapassar 300 caracteres.' if reason.length > 300
    unless actor&.manager? && actor.establishment_id == order.table.establishment_id
      raise Order::InvalidTransition, 'Apenas um gerente deste estabelecimento pode anular pagamentos.'
    end

    establishment = order.table.establishment
    establishment.with_lock do
      order.with_lock do
        lock!
        raise Order::InvalidTransition, 'Este pagamento já foi anulado.' if voided?
        if establishment.cash_closures.active.exists?(business_date: paid_at.in_time_zone.to_date)
          raise Order::InvalidTransition, 'O Caixa deste dia está fechado. Reabre o Caixa antes de corrigir o pagamento.'
        end

        payment_items.includes(:order_item).each do |movement|
          item = movement.order_item
          if item.paid_quantity < movement.quantity
            raise Order::InvalidTransition, 'Os movimentos deste pagamento estão inconsistentes. Contacta o Suporte.'
          end
          item.update!(paid_quantity: item.paid_quantity - movement.quantity)
        end

        update!(voided_at: Time.current, voided_by_user: actor, void_reason: reason)
        order.update!(paid_at: nil, paid_by_user: nil)
      end
    end
  end
end
