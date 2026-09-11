class Staff::SupportTicketsController < Staff::BaseController
  before_action :require_manager
  before_action :reject_support_mode

  def index
    @tickets = current_establishment.support_tickets.includes(:created_by, :assigned_to).recent_first
  end

  def new
    @ticket = current_establishment.support_tickets.new
  end

  def create
    @ticket = current_establishment.support_tickets.new(ticket_params.merge(created_by: current_user))
    first_message = params.dig(:support_ticket, :message).to_s.strip
    SupportTicket.transaction do
      @ticket.save!
      @ticket.messages.create!(author: current_user, body: first_message,
                               attachment: params.dig(:support_ticket, :attachment))
    end
    AuditLogger.record(user: current_user, action: 'support_ticket_created', record: @ticket)
    PlatformPushNotifier.notify_platform(@ticket)
    redirect_to staff_support_ticket_path(@ticket), notice: 'Pedido de apoio enviado.', status: :see_other
  rescue ActiveRecord::RecordInvalid => error
    @ticket.errors.add(:base, error.record.errors.full_messages.join(', ')) unless error.record == @ticket
    render :new, status: :unprocessable_entity
  end

  def show
    @ticket = current_establishment.support_tickets
      .includes(messages: [:author, { attachment_attachment: :blob }]).find(params[:id])
    @message = SupportTicketMessage.new(support_ticket: @ticket)
  end

  private

  def ticket_params
    params.require(:support_ticket).permit(:subject, :category, :priority)
  end

  def reject_support_mode
    head :forbidden if support_mode?
  end
end
