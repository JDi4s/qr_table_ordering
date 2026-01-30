# app/controllers/staff/settings_controller.rb  (FULL FILE — create)
class Staff::SettingsController < ApplicationController
  layout "staff"
  before_action :require_login

  def edit
  end

  def update
    current_user.update!(
      staff_sound_enabled: params.dig(:user, :staff_sound_enabled) == "1"
    )
    redirect_to edit_staff_settings_path, notice: "Settings saved"
  end

  private

  def require_login
    redirect_to login_path unless current_user&.staff?
  end

  def current_user
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  end
end
