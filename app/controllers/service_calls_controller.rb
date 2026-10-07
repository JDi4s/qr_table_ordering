class ServiceCallsController < ApplicationController
  def create
    table = Table.joins(:establishment).where(active: true, deleted_at: nil, establishments: { active: true }).find_by!(qr_token: params[:table_id])
    raise Order::InvalidTransition, 'O serviço está temporariamente pausado. Ainda não é possível chamar um funcionário.' unless table.establishment.accepting_orders?
    table.establishment.with_lock do
      table.with_lock do
        visit = table.table_visits.find_by(id: session.dig(:table_visit_ids, table.id.to_s))
        raise Order::InvalidTransition, 'Aguarda que a equipa ative a mesa.' unless visit&.open? && table.active?
        ServiceCall.request_for!(table)
      end
    end
    redirect_to new_table_order_path(table), notice: 'O funcionário foi chamado à mesa. Aguarde, por favor.', status: :see_other
  end
end
