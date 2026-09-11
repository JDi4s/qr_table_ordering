module ApplicationHelper
  def staff_nav_active?(section)
    paths = {
      orders: %w[staff/orders staff/service_calls staff/order_items],
      tables: %w[staff/tables],
      menu: %w[staff/menu staff/menu_items staff/categories],
      history: %w[staff/orders],
      reports: %w[staff/reports]
    }

    return false unless paths.key?(section)
    return true if section == :history && controller_name == 'orders' && action_name == 'history'

    paths.fetch(section).any? { |path| controller_path.start_with?(path) } &&
      !(section == :orders && action_name == 'history')
  end

  def euros(value)
    number_to_currency(value, unit: '€', separator: ',', delimiter: '.', format: '%n %u')
  end

  def state_label(value)
    {
      'pending' => 'Em avaliação',
      'accepted' => 'Aceite',
      'denied' => 'Rejeitado / cancelado',
      'served' => 'Servido',
      'claimed' => 'Assumida',
      'resolved' => 'Atendida'
    }.fetch(value, value)
  end

  def order_state_label(order)
    order.voided? ? 'Anulado' : state_label(order.status)
  end

  def payment_method_options
    [['Dinheiro', 'cash'], ['Cartão', 'card'], ['MB Way', 'mbway'], ['Outro', 'other']]
  end

  def payment_method_label(value)
    { 'cash' => 'Dinheiro', 'card' => 'Cartão', 'mbway' => 'MB Way', 'other' => 'Outro' }.fetch(value.to_s, value.to_s)
  end

  def audit_action_label(value)
    {
      'order_accepted' => 'aceitou o pedido', 'order_rejected' => 'rejeitou o pedido',
      'order_served' => 'marcou o pedido como servido', 'order_cancelled' => 'cancelou o pedido',
      'payment_received' => 'registou um pagamento', 'service_call_claimed' => 'assumiu uma chamada',
      'service_call_resolved' => 'marcou uma chamada como atendida', 'order_item_reviewed' => 'avaliou um artigo',
      'cash_closed' => 'fechou o caixa', 'order_voided' => 'anulou o pedido',
      'order_deleted' => 'eliminou o pedido', 'team_member_deleted' => 'eliminou um membro',
      'table_deleted' => 'eliminou uma mesa', 'category_deleted' => 'eliminou uma categoria',
      'menu_item_deleted' => 'eliminou um produto'
    }.fetch(value.to_s, value.to_s.humanize.downcase)
  end

  def category_options(categories, parent_id = nil, prefix = '')
    categories
      .select { |category| category.parent_id == parent_id }
      .sort_by(&:name)
      .flat_map do |category|
        [["#{prefix}#{category.name}", category.id]] +
          category_options(categories, category.id, "#{prefix}— ")
      end
  end
end
