module ApplicationHelper
  def euros(value)
    number_to_currency(value, unit: '€', separator: ',', delimiter: '.', format: '%n %u')
  end

  def state_label(value)
    {
      'pending' => 'Em avaliação',
      'accepted' => 'Aceite',
      'needs_customer_action' => 'Aguarda confirmação do cliente',
      'denied' => 'Rejeitado / cancelado',
      'served' => 'Servido',
      'claimed' => 'Assumida',
      'resolved' => 'Atendida'
    }.fetch(value, value)
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
