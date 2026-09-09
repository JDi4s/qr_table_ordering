class Staff::PushSubscriptionsController < Staff::BaseController
  def create
    subscription = params.require(:subscription).permit(:endpoint, keys: [:p256dh, :auth])
    endpoint = subscription[:endpoint].to_s
    keys = subscription[:keys] || {}
    raise Order::InvalidTransition, 'Subscrição de notificações inválida.' if endpoint.blank? || keys[:p256dh].blank? || keys[:auth].blank?

    StaffPushSubscription.transaction do
      StaffPushSubscription.where(endpoint: endpoint).where.not(user_id: current_user.id).delete_all
      current_user.staff_push_subscription&.destroy!
      current_user.create_staff_push_subscription!(
        endpoint: endpoint,
        p256dh: keys[:p256dh],
        auth: keys[:auth]
      )
    end

    render json: { ok: true }
  end

  def destroy
    current_user.staff_push_subscription&.destroy!
    head :no_content
  end
end
