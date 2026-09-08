class Order < ApplicationRecord
  include ActionView::RecordIdentifier
  class InvalidTransition < StandardError; end
  belongs_to :table
  belongs_to :paid_by_user, class_name: 'User', optional: true
  has_one :establishment, through: :table
  has_many :order_items, dependent: :destroy
  has_many :menu_items, through: :order_items
  enum status: { pending: 'pending', accepted: 'accepted', needs_customer_action: 'needs_customer_action', denied: 'denied', served: 'served' }
  scope :unpaid, -> { where(paid_at: nil).where.not(status: 'denied') }
  validates :note, length: { maximum: 1000 }
  validates :customer_token, presence: true
  after_create_commit :broadcast_created
  after_update_commit :broadcast_updated

  def customer_stream
    "table_#{table_id}_customer_#{customer_token}"
  end

  def review_item!(item_id, decision, reason: nil, description: nil, price: nil)
    with_lock do
      ensure_state!('pending')
      raise InvalidTransition, 'Decisão inválida.' unless %w[accepted denied].include?(decision)
      item = order_items.find(item_id)
      changes = { status: decision, denial_reason: decision == 'denied' ? reason.to_s.strip : nil,
                  proposed_description: decision == 'accepted' ? description.to_s.strip.presence : nil }
      if price.present? && decision == 'accepted'
        raise InvalidTransition, 'Explique a alteração de preço ao cliente.' if changes[:proposed_description].blank? && BigDecimal(price.to_s) != item.original_unit_price
        changes[:unit_price] = price
      end
      item.update!(changes)
      refresh_total!
    end
  rescue ArgumentError, TypeError
    raise InvalidTransition, 'Preço inválido.'
  end

  # Staff submit all decisions together; pending lines are accepted as ordered.
  def finalize_review!
    with_lock do
      ensure_state!('pending')
      raise InvalidTransition, 'Pedido sem artigos.' unless order_items.exists?
      order_items.where(status: 'pending').update_all(status: 'accepted', updated_at: Time.current)
      items = order_items.reload
      next_status = if items.all?(&:denied?)
        'denied'
      elsif items.any? { |item| item.denied? || item.proposed_description.present? }
        'needs_customer_action'
      else
        'accepted'
      end
      update!(status: next_status, total: payable_total,
              denial_reason: next_status == 'denied' ? 'Todos os produtos foram rejeitados.' : nil)
    end
  end

  def accept_remaining!
    with_lock do
      ensure_state!('needs_customer_action')
      raise InvalidTransition, 'Não existem artigos confirmados.' unless order_items.where(status: 'accepted').exists?
      raise InvalidTransition, 'O funcionário ainda está a avaliar o pedido.' if order_items.where(status: 'pending').exists?
      update!(status: 'accepted', total: payable_total)
    end
  end

  def reject!(reason, customer: false)
    with_lock do
      ensure_state!('pending', 'needs_customer_action')
      reason = customer ? 'Cancelado pelo cliente.' : reason.to_s.strip
      raise InvalidTransition, 'Indique o motivo da rejeição.' if reason.blank?
      order_items.update_all(status: 'denied', denial_reason: reason, updated_at: Time.current)
      update!(status: 'denied', denial_reason: reason, total: 0)
    end
  end

  def serve!
    with_lock do
      ensure_state!('accepted')
      update!(status: 'served', served_at: Time.current)
    end
  end

  def refresh_total!
    update!(total: payable_total, updated_at: Time.current)
  end

  def payable_total
    order_items.where.not(status: 'denied').sum('unit_price * quantity')
  end

  def paid_total
    payable_total - outstanding_total
  end

  def outstanding_total
    order_items.reject(&:denied?).sum(&:outstanding_total)
  end

  def fully_paid?
    order_items.where.not(status: 'denied').all? { |item| item.remaining_quantity.zero? }
  end

  def paid?
    paid_at.present?
  end

  def mark_paid!(user)
    with_lock do
      ensure_payment_state!
      raise InvalidTransition, 'Este pedido já está marcado como pago.' if paid?

      order_items.where.not(status: 'denied').find_each do |item|
        item.update!(paid_quantity: item.quantity)
      end
      complete_payment!(user)
    end
  end

  def pay_item!(item_id, quantity, user)
    quantity = Integer(quantity)

    with_lock do
      ensure_payment_state!
      raise InvalidTransition, 'Este pedido já está marcado como pago.' if paid?
      raise InvalidTransition, 'Indique uma quantidade válida.' if quantity <= 0

      item = order_items.find(item_id)
      raise InvalidTransition, 'Este artigo não pode ser pago.' unless item.accepted?
      raise InvalidTransition, 'A quantidade indicada é superior ao que falta pagar.' if quantity > item.remaining_quantity

      item.update!(paid_quantity: item.paid_quantity + quantity)
      complete_payment!(user) if fully_paid?
    end
  rescue ArgumentError
    raise InvalidTransition, 'Indique uma quantidade válida.'
  end

  private

  def ensure_payment_state!
    raise InvalidTransition, 'O pedido tem de ser aceite antes de ser pago.' unless accepted? || served?
  end

  def complete_payment!(user)
    return unless fully_paid?

    update!(paid_at: Time.current, paid_by_user: user)
  end

  def ensure_state!(*allowed)
    raise InvalidTransition, 'O pedido já mudou de estado. Atualize a página.' unless allowed.include?(status)
  end

  def broadcast_created
    broadcast_append_to(establishment.staff_stream, target: 'staff_orders_live', partial: 'staff/orders/order_row', locals: { order: self })
  end

  def broadcast_updated
    broadcast_replace_to(customer_stream, target: dom_id(self), partial: 'orders/my_order_card', locals: { order: self })
    if served? || denied?
      broadcast_remove_to(establishment.staff_stream, target: dom_id(self))
    else
      broadcast_replace_to(establishment.staff_stream, target: dom_id(self), partial: 'staff/orders/order_row', locals: { order: self })
    end
    broadcast_replace_to(establishment.staff_stream, target: "order_detail_#{id}", partial: 'staff/orders/detail', locals: { order: self })
  end
end
