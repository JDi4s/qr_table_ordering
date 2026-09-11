class Order < ApplicationRecord
  include ActionView::RecordIdentifier
  class InvalidTransition < StandardError; end
  belongs_to :table
  belongs_to :paid_by_user, class_name: 'User', optional: true
  belongs_to :voided_by_user, class_name: 'User', optional: true
  has_one :establishment, through: :table
  has_many :order_items, dependent: :destroy
  has_many :payments, dependent: :restrict_with_error
  has_many :menu_items, through: :order_items
  has_many :audit_events, as: :auditable, dependent: :nullify
  enum status: { pending: 'pending', accepted: 'accepted', denied: 'denied', served: 'served' }
  scope :not_voided, -> { where(voided_at: nil) }
  scope :unpaid, -> { not_voided.where(paid_at: nil).where.not(status: 'denied') }
  validates :note, length: { maximum: 1000 }
  validates :customer_token, presence: true
  after_create_commit :broadcast_created
  after_create_commit :notify_staff_devices
  after_update_commit :broadcast_updated
  after_destroy_commit :broadcast_destroyed
  before_destroy :prevent_deletion, prepend: true

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
      next_status = items.all?(&:denied?) ? 'denied' : 'accepted'
      update!(status: next_status, total: payable_total,
              denial_reason: next_status == 'denied' ? 'Todos os produtos foram rejeitados.' : nil)
    end
  end

  def reject!(reason, customer: false)
    with_lock do
      ensure_state!('pending')
      raise InvalidTransition, 'O prazo para cancelar este pedido terminou.' if customer && !cancellable_by_customer?
      reason = customer ? 'Cancelado pelo cliente.' : reason.to_s.strip
      raise InvalidTransition, 'Indique o motivo do cancelamento.' if reason.blank?
      order_items.update_all(status: 'denied', denial_reason: reason, updated_at: Time.current)
      update!(status: 'denied', denial_reason: customer ? nil : reason,
              cancellation_reason: reason, cancelled_at: Time.current, total: 0)
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

  def cancellable_by_customer?
    pending? && created_at >= 3.minutes.ago
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

  def voided?
    voided_at.present?
  end

  def mark_paid!(user, payment_method: 'cash')
    with_lock do
      ensure_payment_state!
      ensure_cash_open!
      raise InvalidTransition, 'Este pedido já está marcado como pago.' if paid?

      items = remaining_payment_items
      items.each do |entry|
        item = entry[:order_item]
        item.update!(paid_quantity: item.quantity)
      end
      create_payment!(user, items, payment_method: payment_method)
      complete_payment!(user)
    end
  end

  def pay_item!(item_id, quantity, user, payment_method: 'cash')
    quantity = Integer(quantity)

    with_lock do
      ensure_payment_state!
      ensure_cash_open!
      raise InvalidTransition, 'Este pedido já está marcado como pago.' if paid?
      raise InvalidTransition, 'Indique uma quantidade válida.' if quantity <= 0

      item = order_items.find(item_id)
      raise InvalidTransition, 'Este artigo não pode ser pago.' unless item.accepted?
      raise InvalidTransition, 'A quantidade indicada é superior ao que falta pagar.' if quantity > item.remaining_quantity

      entry = { order_item: item, quantity: quantity, unit_price: item.unit_price, amount: item.unit_price * quantity }
      item.update!(paid_quantity: item.paid_quantity + quantity)
      create_payment!(user, [entry], payment_method: payment_method)
      if fully_paid?
        complete_payment!(user)
      else
        touch
      end
    end
  rescue ArgumentError
    raise InvalidTransition, 'Indique uma quantidade válida.'
  end

  def pay_selected_items!(selections, user, payment_method: 'cash')
    with_lock do
      ensure_payment_state!
      ensure_cash_open!
      raise InvalidTransition, 'Este pedido já está marcado como pago.' if paid?

      entries = selections.each_with_object([]) do |(item_id, raw_quantity), selected|
        quantity = Integer(raw_quantity)
        next if quantity.zero?
        raise InvalidTransition, 'Indique uma quantidade válida.' if quantity.negative?

        item = order_items.find_by(id: item_id)
        raise InvalidTransition, 'Este artigo não pode ser pago.' unless item&.accepted?
        raise InvalidTransition, 'A quantidade indicada é superior ao que falta pagar.' if quantity > item.remaining_quantity

        selected << { order_item: item, quantity: quantity, unit_price: item.unit_price,
                      amount: item.unit_price * quantity }
      end

      raise InvalidTransition, 'Selecione pelo menos um artigo.' if entries.empty?

      entries.each do |entry|
        item = entry[:order_item]
        item.update!(paid_quantity: item.paid_quantity + entry[:quantity])
      end
      create_payment!(user, entries, payment_method: payment_method)
      if fully_paid?
        complete_payment!(user)
      else
        touch
      end
    end
  rescue ArgumentError, TypeError
    raise InvalidTransition, 'Indique uma quantidade válida.'
  end

  private

  def prevent_deletion
    errors.add(:base, 'Os pedidos não podem ser eliminados. Cancele o pedido para manter o histórico.')
    throw :abort
  end

  def ensure_payment_state!
    raise InvalidTransition, 'Este pedido foi anulado.' if voided?
    raise InvalidTransition, 'O pedido tem de ser aceite antes de ser pago.' unless accepted? || served?
  end

  def ensure_cash_open!
    raise InvalidTransition, 'O caixa deste dia já foi fechado.' if establishment.cash_closures.exists?(business_date: Time.current.to_date)
  end

  def complete_payment!(user)
    return unless fully_paid?

    update!(paid_at: Time.current, paid_by_user: user)
  end

  def remaining_payment_items
    order_items.where.not(status: 'denied').filter_map do |item|
      next if item.remaining_quantity.zero?

      { order_item: item, quantity: item.remaining_quantity, unit_price: item.unit_price,
        amount: item.outstanding_total }
    end
  end

  def create_payment!(user, items, payment_method: 'cash')
    unless Payment.payment_methods.key?(payment_method.to_s)
      raise InvalidTransition, 'Método de pagamento inválido.'
    end

    amount = items.sum { |item| item[:amount].to_d }
    return if amount.zero?

    payment = payments.create!(user: user, payment_method: payment_method, amount: amount, paid_at: Time.current)
    items.each do |item|
      payment.payment_items.create!(order_item: item[:order_item], quantity: item[:quantity],
                                    unit_price: item[:unit_price], amount: item[:amount])
    end
    payment
  end

  def ensure_state!(*allowed)
    raise InvalidTransition, 'Este pedido foi anulado.' if voided?
    raise InvalidTransition, 'O pedido já mudou de estado. Atualize a página.' unless allowed.include?(status)
  end

  def broadcast_created
    broadcast_append_to(establishment.staff_stream, target: 'staff_orders_live', partial: 'staff/orders/order_row', locals: { order: self })
    broadcast_active_table
  end

  def notify_staff_devices
    StaffPushNotifier.notify_order(self)
  end

  def broadcast_updated
    broadcast_replace_to(customer_stream, target: dom_id(self), partial: 'orders/my_order_card', locals: { order: self })
    if served? || denied? || voided?
      broadcast_remove_to(establishment.staff_stream, target: dom_id(self))
    else
      broadcast_replace_to(establishment.staff_stream, target: dom_id(self), partial: 'staff/orders/order_row', locals: { order: self })
    end
    broadcast_replace_to(establishment.staff_stream, target: "order_detail_#{id}", partial: 'staff/orders/detail', locals: { order: self })
    broadcast_active_table
  end

  def broadcast_destroyed
    broadcast_remove_to(establishment.staff_stream, target: dom_id(self))
    broadcast_active_table
  end

  def broadcast_active_table
    if table.unpaid_orders.exists?
      broadcast_replace_to(establishment.staff_stream, target: dom_id(table), partial: 'staff/tables/active_table', locals: { table: table })
    else
      broadcast_remove_to(establishment.staff_stream, target: dom_id(table))
    end
  end
end
