class Staff::ServiceCallsController < Staff::BaseController
  def update
    call = current_establishment.service_calls.find(params[:id])
    call.progress!(current_user, params[:status])
    AuditLogger.record(user: current_user, action: params[:status].to_s == 'claimed' ? 'service_call_claimed' : 'service_call_resolved', record: call)
    redirect_to staff_orders_path, notice: 'Chamada atualizada.', status: :see_other
  end
end
