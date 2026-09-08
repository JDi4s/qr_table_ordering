class OrdersChannel < ApplicationCable::Channel
  def subscribed
    if params[:table_token].present?
      @table_id = Table.find_by(qr_token: params[:table_token])&.id
      return reject unless authorized?
      name = "table_#{@table_id}_customer_#{connection.customer_token}"
    else
      return reject unless authorized?
      name = connection.current_user.establishment.staff_stream
    end
    stream_from name, coder: ActiveSupport::JSON do |message|
      # Recheck on every event so suspensions also stop already-open connections.
      if authorized?
        transmit message
      else
        stop_all_streams
      end
    end
  end

  private

  def authorized?
    if params[:table_token].present?
      connection.customer_token.present? && Table.joins(:establishment).where(id: @table_id, active: true, establishments: { active: true }).exists?
    else
      user = User.find_by(id: connection.current_user&.id, active: true)
      user&.venue_access?
    end
  end
end
