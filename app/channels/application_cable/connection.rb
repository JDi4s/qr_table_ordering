module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user, :customer_token
    def connect
      session = env['rack.session']
      self.current_user = User.find_by(id: session[:user_id], active: true)
      self.customer_token = session[:customer_token]
    end
  end
end
