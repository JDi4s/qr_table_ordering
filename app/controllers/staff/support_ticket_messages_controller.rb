class Staff::SupportTicketMessagesController < Staff::BaseController
  before_action :require_manager

  def create
    head :forbidden and return if support_mode?

    ticket = current_establishment.support_tickets.find(params[:support_ticket_id])
    message = ticket.messages.create!(message_params.merge(author: current_user))
    ticket.update!(status: 'in_analysis') if ticket.status == 'waiting_establishment'
    AuditLogger.record(user: current_user, action: 'establishment_replied_to_support', record: ticket)
    PlatformPushNotifier.notify_platform(ticket, message)
    redirect_to staff_support_ticket_path(ticket), notice: 'Mensagem enviada.', status: :see_other
  end

  private

  def message_params
    params.require(:support_ticket_message).permit(:body, :attachment)
  end
end
