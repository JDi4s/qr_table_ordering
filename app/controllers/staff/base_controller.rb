class Staff::BaseController < ApplicationController
  layout 'staff'
  before_action :require_venue_access
  before_action :require_password_change

  private

  def require_venue_access
    redirect_to login_path, alert: 'Inicie sessão numa conta ativa.' unless current_user&.venue_access?
  end

  def require_manager
    head :forbidden unless current_user&.manager?
  end

  def require_password_change
    return unless current_user&.staff? && current_user.must_change_password?
    return if controller_path == 'staff/settings'

    redirect_to edit_staff_settings_path, alert: 'Altere a palavra-passe temporária antes de continuar.'
  end
end
