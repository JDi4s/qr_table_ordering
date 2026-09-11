module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user, :customer_token, :support_establishment
    def connect
      session = env['rack.session']
      self.current_user = User.find_by(id: session[:user_id], active: true)
      self.customer_token = session[:customer_token]
      support_session = SupportSession.active.find_by(id: session[:support_session_id], platform_admin_id: current_user&.id)
      self.support_establishment = support_session&.establishment
    end
  end
end
