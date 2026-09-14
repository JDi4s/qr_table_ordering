class Staff::PaymentsController < Staff::BaseController
  before_action :require_manager

  def void
    payment = current_establishment.payments.find(params[:id])
    payment.void!(current_user, reason: params[:void_reason])
    AuditLogger.record(
      user: current_user,
      action: 'payment_voided',
      record: payment.order,
      metadata: {
        payment_id: payment.id,
        amount: payment.amount.to_s,
        payment_method: payment.payment_method,
        reason: payment.void_reason
      }
    )
    redirect_back fallback_location: staff_order_path(payment.order),
                  notice: "Pagamento de #{helpers.euros(payment.amount)} anulado. Já podes registar o pagamento correto.",
                  status: :see_other
  end
end
