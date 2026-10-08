class CustomerMenuBroadcast
  def self.stream_name(establishment)
    "establishment_#{establishment.id}_customer_menu"
  end

  def self.message(establishment)
    establishment = Establishment.find(establishment.id)
    categories = establishment.categories.not_archived.includes(:menu_items, :children)
      .where(available: true).order(:name)
    ApplicationController.render(template: 'orders/menu_update', formats: [:turbo_stream],
      locals: { categories: categories, establishment: establishment })
  end

  def self.call(establishment)
    ActionCable.server.broadcast(stream_name(establishment), message(establishment))
  end
end
