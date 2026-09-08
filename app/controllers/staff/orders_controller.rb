class Staff::OrdersController < Staff::BaseController
  def index
    @orders = current_establishment.orders.includes(:table, order_items: :menu_item).where.not(status: %w[served denied]).order(:created_at)
    @service_calls = current_establishment.service_calls.includes(:table, :assigned_user).where.not(status: 'resolved').order(:created_at)
  end

  def show
    @order = current_establishment.orders.includes(:table, order_items: :menu_item).find(params[:id])
  end

  def update
    order = current_establishment.orders.find(params[:id])
    case params[:status]
    when 'accepted' then order.finalize_review!
    when 'denied' then order.reject!(params[:denial_reason])
    when 'served' then order.serve!
    else raise Order::InvalidTransition, 'Estado inválido.'
    end
    redirect_to staff_order_path(order), notice: 'Pedido atualizado.', status: :see_other
  end

  def history
    @orders = current_establishment.orders.includes(:table, order_items: :menu_item).where(status: %w[served denied]).order(created_at: :desc).limit(200)
  end
end
