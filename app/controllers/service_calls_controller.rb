class ServiceCallsController < ApplicationController
  def create
    table = Table.joins(:establishment).where(active: true, deleted_at: nil, establishments: { active: true }).find_by!(qr_token: params[:table_id])
    raise Order::InvalidTransition, 'O serviço está temporariamente pausado. Ainda não é possível chamar um funcionário.' unless table.establishment.accepting_orders?

    ServiceCall.request_for!(table)
    redirect_to new_table_order_path(table), notice: 'O funcionário foi chamado à mesa. Aguarde, por favor.', status: :see_other
  end
end
