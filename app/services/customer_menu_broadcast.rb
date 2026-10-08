require 'set'

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

  # Bulk imports publish one complete menu after the transaction commits.
  def self.batch
    previous = ActiveSupport::IsolatedExecutionState[:customer_menu_batch]
    pending = previous || Set.new
    ActiveSupport::IsolatedExecutionState[:customer_menu_batch] = pending
    begin
      result = yield
      completed = true
      result
    ensure
      ActiveSupport::IsolatedExecutionState[:customer_menu_batch] = previous
      pending.each { |id| call(Establishment.find(id)) } if completed && previous.nil?
    end
  end

  def self.call(establishment)
    if (pending = ActiveSupport::IsolatedExecutionState[:customer_menu_batch])
      pending.add(establishment.id)
      return
    end
    ActionCable.server.broadcast(stream_name(establishment), message(establishment))
  end
end
