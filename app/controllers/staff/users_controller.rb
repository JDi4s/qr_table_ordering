class Staff::UsersController < Staff::BaseController
  before_action :require_manager
  def index
    @users = current_establishment.users.order(:name, :username, :email)
    @user = current_establishment.users.new(role: 'staff')
    @production_areas = current_establishment.available_production_areas
  end
  def create
    values = user_params
    area_ids = values.delete(:production_area_ids)
    values[:must_change_password] = true if values[:role].to_s == 'staff'
    user = current_establishment.users.create!(values)
    sync_production_areas!(user, area_ids)
    redirect_to staff_users_path, notice: 'Utilizador criado.'
  end
  def update
    user = current_establishment.users.find(params[:id])
    raise Order::InvalidTransition, 'Não pode alterar a sua própria conta nesta área.' if user == current_user
    values = user_params
    area_ids = values.delete(:production_area_ids)
    user.update!(values)
    sync_production_areas!(user, area_ids)
    redirect_to staff_users_path, notice: 'Utilizador atualizado.', status: :see_other
  end
  private
  def user_params
    values = params.require(:user).permit(:name, :username, :email, :password, :role, :active, production_area_ids: [])
    values.delete(:password) if values[:password].blank?
    values.delete(:email) if values[:email].blank?
    values[:must_change_password] = false if values[:password].present? && values[:role].to_s == 'manager'
    raise Order::InvalidTransition, 'Perfil inválido.' if values[:role].present? && !%w[staff manager].include?(values[:role])
    values
  end

  def sync_production_areas!(user, ids)
    return unless current_establishment.production_areas_enabled?

    allowed_ids = current_establishment.available_production_areas.where(id: Array(ids)).pluck(:id)
    user.production_area_ids = user.staff? ? allowed_ids : []
  end
end
