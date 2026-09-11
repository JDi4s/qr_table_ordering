class ApplicationController < ActionController::Base
  helper_method :current_user, :current_establishment, :active_support_session, :support_mode?, :manager_access?
  rescue_from Order::InvalidTransition, with: :invalid_operation
  rescue_from ActiveRecord::RecordInvalid, with: :invalid_record

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id], active: true, deleted_at: nil)
  end

  def current_establishment
    return active_support_session&.establishment if current_user&.platform_admin?

    current_user&.establishment
  end

  def active_support_session
    return unless current_user&.platform_admin? && session[:support_session_id].present?

    @active_support_session ||= SupportSession.active
      .includes(:establishment, :support_ticket)
      .find_by(id: session[:support_session_id], platform_admin_id: current_user.id)
  end

  def support_mode?
    active_support_session.present?
  end

  def manager_access?
    current_user&.manager? || support_mode?
  end

  def invalid_operation(error)
    redirect_back fallback_location: root_path, alert: error.message, status: :see_other
  end

  def invalid_record(error)
    redirect_back fallback_location: root_path, alert: error.record.errors.full_messages.join(', '), status: :see_other
  end
end
