class Admin::SupportSessionsController < Admin::BaseController
  skip_before_action :enforce_support_session_boundary, only: :destroy

  def create
    establishment = Establishment.find(params[:establishment_id])
    ticket = establishment.support_tickets.find_by(id: params[:support_ticket_id]) if params[:support_ticket_id].present?
    current_user.support_sessions.active.update_all(ended_at: Time.current, updated_at: Time.current)
    support_session = current_user.support_sessions.create!(
      establishment: establishment,
      support_ticket: ticket,
      reason: params[:reason].to_s.strip.presence,
      started_at: Time.current,
      expires_at: 30.minutes.from_now
    )
    platform_admin_id = current_user.id
    reset_session
    session[:user_id] = platform_admin_id
    session[:support_session_id] = support_session.id
    AuditLogger.record(user: current_user, action: 'support_access_started', record: support_session,
                       metadata: { reason: support_session.reason, ticket_id: ticket&.id })
    redirect_to staff_menu_path, notice: "Entraste em #{establishment.name} como Suporte.", status: :see_other
  end

  def destroy
    support_session = current_user.support_sessions.find(params[:id])
    AuditLogger.record(user: current_user, action: 'support_access_ended', record: support_session)
    support_session.finish!
    reset_session
    redirect_to login_path, notice: 'Intervenção terminada. Inicia sessão novamente para voltar à administração.', status: :see_other
  end
end
