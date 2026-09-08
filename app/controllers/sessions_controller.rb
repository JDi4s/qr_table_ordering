class SessionsController < ApplicationController
  def new; end

  def create
    user = User.find_by(email: params[:email].to_s.strip.downcase)
    if user&.active? && user.authenticate(params[:password]) && (user.platform_admin? || user.venue_access?)
      reset_session
      session[:user_id] = user.id
      redirect_to(user.platform_admin? ? admin_establishments_path : staff_orders_path)
    else
      flash.now[:alert] = 'Email ou palavra-passe inválidos, ou conta suspensa.'
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session
    redirect_to login_path, status: :see_other
  end
end
