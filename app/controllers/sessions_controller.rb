class SessionsController < ApplicationController
  def new; end

  def create
    identifier = (params[:identifier].presence || params[:email]).to_s.strip.downcase
    user = User.where('lower(email) = :identifier OR lower(username) = :identifier', identifier: identifier).first
    if user&.active? && user.authenticate(params[:password]) && (user.platform_admin? || user.venue_access?)
      reset_session
      session[:user_id] = user.id
      redirect_to(user.platform_admin? ? admin_establishments_path : (user.must_change_password? ? edit_staff_settings_path : staff_orders_path))
    else
      flash.now[:alert] = 'Utilizador/email ou palavra-passe inválidos, ou conta suspensa.'
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    current_user&.staff_push_subscription&.destroy!
    reset_session
    redirect_to login_path, status: :see_other
  end
end
