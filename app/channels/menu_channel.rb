class MenuChannel < ApplicationCable::Channel
  def subscribed
    @table_id = Table.find_by(qr_token: params[:table_token])&.id if params[:table_token].present?
    return reject unless authorized?

    establishment = Table.find(@table_id).establishment
    stream_from CustomerMenuBroadcast.stream_name(establishment), coder: ActiveSupport::JSON do |message|
      authorized? ? transmit(message) : stop_all_streams
    end
    # A fresh snapshot also catches updates missed while the device was offline.
    transmit CustomerMenuBroadcast.message(establishment)
  end

  private

  def authorized?
    connection.customer_token.present? && Table.joins(:establishment)
      .where(id: @table_id, active: true, deleted_at: nil, establishments: { active: true }).exists?
  end
end
