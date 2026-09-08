class ApplicationController < ActionController::Base
  helper_method :current_user, :current_establishment
  rescue_from Order::InvalidTransition, with: :invalid_operation
  rescue_from ActiveRecord::RecordInvalid, with: :invalid_record

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id], active: true)
  end

  def current_establishment
    current_user&.establishment
  end

  def invalid_operation(error)
    redirect_back fallback_location: root_path, alert: error.message, status: :see_other
  end

  def invalid_record(error)
    redirect_back fallback_location: root_path, alert: error.record.errors.full_messages.join(', '), status: :see_other
  end
end
