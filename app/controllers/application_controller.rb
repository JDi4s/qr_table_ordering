# app/controllers/application_controller.rb  (FULL FILE — replace)
class ApplicationController < ActionController::Base
  helper_method :current_user

  private

  def current_user
    return @current_user if defined?(@current_user)
    @current_user = session[:user_id] ? User.find_by(id: session[:user_id]) : nil
  end
end
