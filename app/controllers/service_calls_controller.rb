class ServiceCallsController < ApplicationController
  def create
    table = Table.joins(:establishment).where(active: true, establishments: { active: true }).find_by!(qr_token: params[:table_id])
    ServiceCall.request_for!(table)
    redirect_to new_table_order_path(table), notice: 'O funcionário foi chamado à mesa. Aguarde, por favor.', status: :see_other
  end
end
