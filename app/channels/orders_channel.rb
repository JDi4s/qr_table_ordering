class OrdersChannel < ApplicationCable::Channel
  def subscribed
    if params[:table_token].present?
      table = Table.joins(:establishment).where(active: true, establishments: { active: true }).find_by(qr_token: params[:table_token])
      return reject unless table && connection.customer_token.present?
      stream_from "table_#{table.id}_customer_#{connection.customer_token}"
    else
      return reject unless connection.current_user&.venue_access?
      stream_from connection.current_user.establishment.staff_stream
    end
  end
end
