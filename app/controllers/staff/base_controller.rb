class Staff::BaseController < ApplicationController
  layout 'staff'
  before_action :require_venue_access

  private

  def require_venue_access
    redirect_to login_path, alert: 'Inicie sessão numa conta ativa.' unless current_user&.venue_access?
  end

  def require_manager
    head :forbidden unless current_user&.manager?
  end
end
