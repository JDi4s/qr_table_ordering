class Admin::BaseController < ApplicationController
  layout 'admin'
  before_action :require_platform_admin

  private

  def require_platform_admin
    head :forbidden unless current_user&.platform_admin?
  end
end
