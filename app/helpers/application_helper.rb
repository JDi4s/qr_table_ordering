module ApplicationHelper
  def euros(value)
    number_to_currency(value, unit: '€', separator: ',', delimiter: '.', format: '%n %u')
  end
  def state_label(value)
    { 'pending' => 'Em avaliação', 'accepted' => 'Aceite', 'needs_customer_action' => 'Aguarda confirmação do cliente',
      'denied' => 'Rejeitado / cancelado', 'served' => 'Servido', 'claimed' => 'Assumida', 'resolved' => 'Atendida' }.fetch(value, value)
  end
end
