class PreparationTask < ApplicationRecord
  STATES = %w[preparing ready delivered cancelled].freeze
  belongs_to :order_item
  belongs_to :production_area, optional: true
  belongs_to :updated_by, class_name: 'User', optional: true
  has_one :order, through: :order_item
  validates :state, inclusion: { in: STATES }
  validates :name, :component_key, presence: true
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }

  def self.build_for!(order)
    return unless order.establishment.service_division_enabled?
    order.order_items.where(status: 'accepted').each do |item|
      components = if item.lunch_selection['kind'] == 'combo'
        Array(item.lunch_selection['choices']).select { |choice| choice['menu_item_id'].present? }.map { |choice| [choice['group'], choice['name'], choice['menu_item_id']] }
      else
        [['product', item.display_name, item.menu_item_id]]
      end
      components.each do |key, name, product_id|
        product = order.establishment.menu_items.find_by(id: product_id)
        area = order.table.service_zone&.destination(product&.preparation_key || 'counter')
        area ||= order.establishment.available_production_areas.find_by(id: product&.production_area_id)
        area ||= order.establishment.available_production_areas.find_by(preparation_key: product&.preparation_key || 'counter')
        item.preparation_tasks.find_or_create_by!(component_key: key) { |task| task.assign_attributes(name: name, quantity: item.quantity, production_area: area) }
      end
    end
  end

  def transition!(next_state, user)
    unless user.venue_access? && user.establishment_id == order.establishment.id && (!user.preparation_staff? || user.production_areas.where(active: true).exists?(id: production_area_id))
      raise Order::InvalidTransition, 'Não tens acesso a este posto.'
    end
    order.with_lock do
      reload
      return if state == next_state
      raise Order::InvalidTransition, 'Este pedido já terminou.' unless order.accepted? && !order.voided?
      allowed = (next_state == 'ready' && state == 'preparing') || (next_state == 'delivered' && state == 'ready' && !user.preparation_staff?)
      raise Order::InvalidTransition, 'A preparação já mudou de estado.' unless allowed
      update!(state: next_state, updated_by: user, ready_at: next_state == 'ready' ? Time.current : ready_at,
        delivered_at: next_state == 'delivered' ? Time.current : nil)
      order.serve! if next_state == 'delivered' && order.preparation_tasks.where.not(state: %w[delivered cancelled]).none?
      order.touch unless order.served?
    end
  end
end

