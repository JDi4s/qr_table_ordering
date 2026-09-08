class Staff::OrderItemsController < Staff::BaseController
  def update
    item = OrderItem.joins(order: :table).where(tables: { establishment_id: current_establishment.id }).find(params[:id])
    values = params.require(:order_item).permit(:status, :denial_reason, :proposed_description, :unit_price)
    item.order.review_item!(item.id, values[:status], reason: values[:denial_reason], description: values[:proposed_description], price: values[:unit_price])
    redirect_to staff_order_path(item.order), notice: 'Decisão guardada. Conclua a avaliação para avisar o cliente.', status: :see_other
  end
end
