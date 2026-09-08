class Staff::UsersController < Staff::BaseController
  before_action :require_manager
  def index
    @users = current_establishment.users.order(:email)
    @user = current_establishment.users.new(role: 'staff')
  end
  def create
    current_establishment.users.create!(user_params)
    redirect_to staff_users_path, notice: 'Utilizador criado.'
  end
  def update
    user = current_establishment.users.find(params[:id])
    raise Order::InvalidTransition, 'Não pode alterar a sua própria conta nesta área.' if user == current_user
    user.update!(user_params)
    redirect_to staff_users_path, notice: 'Utilizador atualizado.', status: :see_other
  end
  private
  def user_params
    values = params.require(:user).permit(:name, :email, :password, :role, :active)
    values.delete(:password) if values[:password].blank?
    raise Order::InvalidTransition, 'Perfil inválido.' if values[:role].present? && !%w[staff manager].include?(values[:role])
    values
  end
end
