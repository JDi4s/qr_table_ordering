class Admin::BaseController < ApplicationController
  layout 'admin'
  before_action :require_platform_admin

  private

  def require_platform_admin
    return if current_user&.platform_admin?

    if current_user&.staff_account?
      redirect_to staff_orders_path, alert: 'Esta área é exclusiva da administração da plataforma.'
    else
      redirect_to login_path, alert: 'Inicia sessão com a conta da administração da plataforma.'
    end
  end
end
