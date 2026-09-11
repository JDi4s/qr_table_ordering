class Admin::SupportTicketMessagesController < Admin::BaseController
  def create
    ticket = SupportTicket.find(params[:support_ticket_id])
    message = ticket.messages.create!(message_params.merge(author: current_user))
    ticket.update!(assigned_to: current_user, status: 'waiting_establishment') if ticket.status != 'resolved'
    AuditLogger.record(user: current_user, action: 'support_replied', record: ticket)
    PlatformPushNotifier.notify_establishment(ticket, message)
    redirect_to admin_support_ticket_path(ticket), notice: 'Resposta enviada.', status: :see_other
  end

  private

  def message_params
    params.require(:support_ticket_message).permit(:body, :attachment)
  end
end
