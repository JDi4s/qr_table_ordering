class Admin::BaseController < ApplicationController
  layout 'admin'
  before_action :require_platform_admin
  before_action :enforce_support_session_boundary

  private

  def require_platform_admin
    return if current_user&.platform_admin?

    if current_user&.staff_account?
      redirect_to staff_orders_path, alert: 'Esta área é exclusiva da administração da plataforma.'
    else
      redirect_to login_path, alert: 'Inicia sessão com a conta da administração da plataforma.'
    end
  end

  def enforce_support_session_boundary
    return if session[:support_session_id].blank?

    if active_support_session
      redirect_to staff_menu_path, alert: 'Termina a intervenção de Suporte antes de voltar à administração.'
    else
      expired_session = current_user.support_sessions.find_by(id: session[:support_session_id])
      if expired_session && expired_session.ended_at.nil?
        AuditLogger.record(user: current_user, action: 'support_access_ended', record: expired_session,
                           metadata: { expired: true })
      end
      expired_session&.finish!
      reset_session
      redirect_to login_path, alert: 'A intervenção de Suporte terminou. Inicia sessão novamente.'
    end
  end
end
