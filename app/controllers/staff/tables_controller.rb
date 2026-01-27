class Staff::TablesController < ApplicationController
  before_action :require_login

  def index
    @tables = Table.all
  end

  private

  def require_login
    unless current_user&.staff?
      redirect_to login_path, alert: "Please log in as staff"
    end
  end

  def current_user
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  end
end
