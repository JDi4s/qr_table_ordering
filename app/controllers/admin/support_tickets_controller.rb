class Admin::SupportTicketsController < Admin::BaseController
  before_action :set_ticket, only: [:show, :update]

  def index
    @status = SupportTicket::STATUSES.include?(params[:status].to_s) ? params[:status].to_s : 'unresolved'
    scope = SupportTicket.includes(:establishment, :created_by, :assigned_to).recent_first
    scope = scope.where(establishment_id: params[:establishment_id]) if params[:establishment_id].present?
    @tickets = @status == 'unresolved' ? scope.unresolved : scope.where(status: @status)
  end

  def show
    @message = @ticket.messages.new
  end

  def update
    @ticket.update!(ticket_params.merge(assigned_to: current_user))
    AuditLogger.record(user: current_user, action: 'support_ticket_updated', record: @ticket,
                       metadata: { status: @ticket.status, priority: @ticket.priority })
    PlatformPushNotifier.notify_establishment(@ticket, nil) if @ticket.saved_change_to_status?
    redirect_to admin_support_ticket_path(@ticket), notice: 'Ticket atualizado.', status: :see_other
  end

  private

  def set_ticket
    @ticket = SupportTicket.includes(messages: [:author, { attachment_attachment: :blob }]).find(params[:id])
  end

  def ticket_params
    params.require(:support_ticket).permit(:status, :priority)
  end
end
