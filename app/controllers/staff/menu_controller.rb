class Staff::MenuController < ApplicationController
  layout "staff"
  before_action :require_login

  def index
    @categories = Category.includes(:menu_items).order(:name)
  end

  private

  def require_login
    redirect_to login_path unless current_user&.staff?
  end
end
