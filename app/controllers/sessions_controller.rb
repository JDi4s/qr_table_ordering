class SessionsController < ApplicationController
  def new; end

  def create
    identifier = (params[:identifier].presence || params[:email]).to_s.strip.downcase
    user = User.where(deleted_at: nil)
      .where('lower(email) = :identifier OR lower(username) = :identifier', identifier: identifier).first
    if user&.active? && user.authenticate(params[:password]) && (user.platform_admin? || user.venue_access?)
      finish_current_support_session!
      remove_current_device_subscription
      reset_session
      session[:user_id] = user.id
      redirect_to(user.platform_admin? ? admin_establishments_path : (user.must_change_password? ? edit_staff_settings_path : (user.preparation_staff? ? staff_preparations_path : staff_orders_path)))
    else
      flash.now[:alert] = 'Utilizador/email ou palavra-passe inválidos, ou conta suspensa.'
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    finish_current_support_session!
    remove_current_device_subscription
    reset_session
    redirect_to login_path, status: :see_other
  end

  private

  def remove_current_device_subscription
    endpoint = session[:push_endpoint]
    return if endpoint.blank? || current_user.blank?

    current_user.staff_push_subscriptions.where(endpoint: endpoint).destroy_all
  end

  def finish_current_support_session!
    return if session[:support_session_id].blank? || current_user.blank?

    support_session = current_user.support_sessions.find_by(id: session[:support_session_id])
    return if support_session.blank? || support_session.ended_at.present?

    AuditLogger.record(user: current_user, action: 'support_access_ended', record: support_session)
    support_session.finish!
  end
end
