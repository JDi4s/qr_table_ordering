class Staff::BaseController < ApplicationController
  layout 'staff'
  before_action :require_venue_access
  before_action :require_password_change
  before_action :restrict_support_operations

  private

  def require_venue_access
    return if current_user&.venue_access? || support_mode?

    if current_user&.platform_admin?
      session.delete(:support_session_id)
      redirect_to admin_establishments_path, alert: 'A intervenção de Suporte terminou ou expirou.'
    else
      redirect_to login_path, alert: 'Inicie sessão numa conta ativa.'
    end
  end

  def require_manager
    head :forbidden unless manager_access?
  end

  def require_password_change
    return unless current_user&.staff? && current_user.must_change_password?
    return if controller_path == 'staff/settings'

    redirect_to edit_staff_settings_path, alert: 'Altere a palavra-passe temporária antes de continuar.'
  end

  def restrict_support_operations
    return unless support_mode?
    return if request.get? || request.head?
    return if %w[staff/categories staff/menu_items staff/tables staff/users staff/settings].include?(controller_path)

    redirect_back fallback_location: staff_orders_path,
                  alert: 'O Suporte pode consultar esta área, mas não pode alterar pedidos, pagamentos ou o Caixa.',
                  status: :see_other
  end
end
