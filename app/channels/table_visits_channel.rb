class TableVisitsChannel < ApplicationCable::Channel
  def subscribed
    @table_id = Table.find_by(qr_token: params[:table_token])&.id if params[:table_token].present?
    return reject unless authorized?
    venue = connection.current_user&.establishment || connection.support_establishment
    stream = @table_id ? "table_access_#{@table_id}" : "table_activation_#{venue.id}"
    stream_from stream, coder: ActiveSupport::JSON do |message|
      authorized? ? transmit(message) : stop_all_streams
    end
  end

  private

  def authorized?
    if params[:table_token].present?
      connection.customer_token.present? && Table.joins(:establishment)
        .where(id: @table_id, active: true, deleted_at: nil, establishments: { active: true }).exists?
    else
      user = User.find_by(id: connection.current_user&.id, active: true, deleted_at: nil)
      user&.venue_access? || (user&.platform_admin? && Establishment.where(id: connection.support_establishment&.id, active: true).exists?)
    end
  end
end
