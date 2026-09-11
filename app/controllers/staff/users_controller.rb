class Staff::UsersController < Staff::BaseController
  before_action :require_manager

  def index
    prepare_index
  end

  def create
    values = user_params
    area_ids = values.delete(:production_area_ids)
    values[:must_change_password] = true if values[:role] == 'staff'
    @user = current_establishment.users.new(values)

    User.transaction do
      @user.save!
      sync_production_areas!(@user, area_ids)
    end

    redirect_to staff_users_path(anchor: "team-user-#{@user.id}"), notice: 'Utilizador criado.'
  rescue ActiveRecord::RecordInvalid => error
    prepare_index(new_user: @user)
    flash.now[:alert] = error.record.errors.full_messages.join(', ')
    render :index, status: :unprocessable_entity
  end

  def update
    user = current_establishment.users.where(deleted_at: nil).find(params[:id])
    raise Order::InvalidTransition, 'Não pode alterar a sua própria conta nesta área.' if user == current_user

    values = user_params
    area_ids = values.delete(:production_area_ids)
    next_role = values[:role].presence || user.role
    values[:must_change_password] = true if next_role == 'staff' && (values[:password].present? || !user.staff?)
    values[:must_change_password] = false if next_role == 'manager'
    user.assign_attributes(values)
    @editing_user = user

    User.transaction do
      user.save!
      sync_production_areas!(user, area_ids)
    end

    redirect_to staff_users_path(anchor: "team-user-#{user.id}"), notice: 'Utilizador atualizado.', status: :see_other
  rescue ActiveRecord::RecordInvalid => error
    prepare_index
    @editing_user = error.record
    @users.map! { |candidate| candidate.id == @editing_user.id ? @editing_user : candidate }
    flash.now[:alert] = error.record.errors.full_messages.join(', ')
    render :index, status: :unprocessable_entity
  end

  def destroy
    user = current_establishment.users.where(deleted_at: nil).find(params[:id])
    raise Order::InvalidTransition, 'Não pode eliminar a sua própria conta.' if user == current_user
    raise Order::InvalidTransition, 'Este funcionário tem uma chamada em curso. Conclua-a antes de eliminar.' if user.involved_in_open_service?
    if user.manager? && !current_establishment.users.where(role: 'manager', active: true, deleted_at: nil).where.not(id: user.id).exists?
      raise Order::InvalidTransition, 'Não pode eliminar o último gerente ativo.'
    end

    identity = user.name.presence || user.login_identifier
    metadata = { deleted_user_id: user.id, name: identity, role: user.role }
    User.transaction do
      user.staff_push_subscription&.destroy!
      user.update!(active: false, deleted_at: Time.current)
      AuditLogger.record(user: current_user, action: 'team_member_deleted', metadata: metadata)
    end

    redirect_to staff_users_path, notice: "#{identity} foi eliminado da equipa.", status: :see_other
  end

  private

  def prepare_index(new_user: nil)
    base = current_establishment.users.where(deleted_at: nil)
    @team_totals = {
      total: base.count,
      active: base.where(active: true).count,
      staff: base.where(role: 'staff').count,
      managers: base.where(role: 'manager').count
    }

    @team_query = params[:q].to_s.strip
    @team_role = params[:role].to_s if %w[staff manager].include?(params[:role].to_s)
    @team_status = params[:status].to_s if %w[active inactive].include?(params[:status].to_s)

    scope = base.includes(:production_areas, :staff_push_subscription)
    if @team_query.present?
      term = "%#{ActiveRecord::Base.sanitize_sql_like(@team_query)}%"
      scope = scope.where('users.name ILIKE :term OR users.username ILIKE :term OR users.email ILIKE :term', term: term)
    end
    scope = scope.where(role: @team_role) if @team_role.present?
    scope = scope.where(active: @team_status == 'active') if @team_status.present?

    @users = scope.order(active: :desc, name: :asc, username: :asc, email: :asc).to_a
    @user = new_user || current_establishment.users.new(role: 'staff')
    @production_areas = current_establishment.available_production_areas
  end

  def user_params
    values = params.require(:user)
      .permit(:name, :username, :email, :password, :role, :active, production_area_ids: [])
      .to_h
      .symbolize_keys
    values.delete(:password) if values[:password].blank?
    values[:email] = nil if values.key?(:email) && values[:email].blank?
    raise Order::InvalidTransition, 'Perfil inválido.' if values[:role].present? && !%w[staff manager].include?(values[:role])

    values
  end

  def sync_production_areas!(user, ids)
    return unless current_establishment.production_areas_enabled?

    allowed_ids = current_establishment.available_production_areas.where(id: Array(ids)).pluck(:id)
    user.production_area_ids = user.staff? ? allowed_ids : []
  end
end
