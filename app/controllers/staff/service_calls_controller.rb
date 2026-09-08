class Staff::ServiceCallsController < Staff::BaseController
  def update
    current_establishment.service_calls.find(params[:id]).progress!(current_user, params[:status])
    redirect_to staff_orders_path, notice: 'Chamada atualizada.', status: :see_other
  end
end
