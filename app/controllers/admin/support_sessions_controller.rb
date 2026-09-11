class Admin::SupportSessionsController < Admin::BaseController
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
    session[:support_session_id] = support_session.id
    AuditLogger.record(user: current_user, action: 'support_access_started', record: support_session,
                       metadata: { reason: support_session.reason, ticket_id: ticket&.id })
    redirect_to staff_menu_path, notice: "Entraste em #{establishment.name} como Suporte.", status: :see_other
  end

  def destroy
    support_session = current_user.support_sessions.find(params[:id])
    AuditLogger.record(user: current_user, action: 'support_access_ended', record: support_session)
    support_session.finish!
    session.delete(:support_session_id)
    redirect_to admin_establishments_path, notice: 'Intervenção terminada.', status: :see_other
  end
end
