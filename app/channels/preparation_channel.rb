class PreparationChannel < ApplicationCable::Channel
  def subscribed
    user = connection.current_user
    return reject unless user&.venue_access?
    stream_from "preparation_user_#{user.id}", coder: ActiveSupport::JSON do |message|
      current = User.find_by(id: user.id)
      if current&.venue_access?
        transmit message
      else
        stop_all_streams
      end
    end
  end
end
