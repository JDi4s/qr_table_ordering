class Admin::PushSubscriptionsController < Admin::BaseController
  def create
    subscription = params.require(:subscription).permit(:endpoint, keys: [:p256dh, :auth])
    endpoint = subscription[:endpoint].to_s
    keys = subscription[:keys] || {}
    head :unprocessable_entity and return if endpoint.blank? || keys[:p256dh].blank? || keys[:auth].blank?

    StaffPushSubscription.register_for!(current_user, endpoint: endpoint, p256dh: keys[:p256dh], auth: keys[:auth])
    session[:push_endpoint] = endpoint
    render json: { ok: true }
  end

  def destroy
    endpoint = params[:endpoint].to_s
    head :unprocessable_entity and return if endpoint.blank?

    current_user.staff_push_subscriptions.where(endpoint: endpoint).destroy_all
    session.delete(:push_endpoint) if session[:push_endpoint] == endpoint
    head :no_content
  end
end
