class SupportTicketsChannel < ApplicationCable::Channel
  def subscribed
    return reject unless authorized?

    @subscription_stream = stream_name
    stream_from @subscription_stream, coder: ActiveSupport::JSON do |message|
      if authorized? && stream_name == @subscription_stream
        transmit message
      else
        stop_all_streams
      end
    end
  end

  private

  def authorized?
    @user = User.find_by(id: connection.current_user&.id, active: true, deleted_at: nil)
    return false unless @user
    return false if connection.support_establishment.present?
    return false unless @user.platform_admin? || (@user.manager? && @user.venue_access?)

    case params[:scope]
    when 'notifications'
      true
    when 'list'
      @user.manager? || SupportTicketBroadcaster::FILTERS.include?(params[:status].to_s)
    when 'ticket'
      @ticket = SupportTicket.find_by(id: params[:ticket_id])
      @ticket && (@user.platform_admin? || @ticket.establishment_id == @user.establishment_id)
    else
      false
    end
  end

  def stream_name
    case params[:scope]
    when 'notifications'
      "support_notifications_user_#{@user.id}"
    when 'ticket'
      "support_ticket_#{@ticket.id}_#{@user.platform_admin? ? 'admin' : 'staff'}"
    when 'list'
      if @user.platform_admin?
        establishment_id = params[:establishment_id].present? ? params[:establishment_id].to_i : nil
        SupportTicketBroadcaster.admin_list_stream(params[:status].to_s, establishment_id)
      else
        "support_list_establishment_#{@user.establishment_id}"
      end
    end
  end
end
