class Admin::EstablishmentsController < ApplicationController
  before_action :require_platform_admin
  def index
    @establishments = Establishment.order(:name)
  end
  def new
    @establishment = Establishment.new
  end
  def create
    @establishment = Establishment.new(establishment_params)
    Establishment.transaction do
      @establishment.save!
      @establishment.users.create!(params.require(:manager).permit(:name, :email, :password).merge(role: 'manager'))
    end
    redirect_to admin_establishments_path, notice: 'Estabelecimento e gerente criados.'
  rescue ActiveRecord::RecordInvalid => error
    flash.now[:alert] = error.record.errors.full_messages.join(', ')
    render :new, status: :unprocessable_entity
  end
  def edit
    @establishment = Establishment.find(params[:id])
  end
  def update
    @establishment = Establishment.find(params[:id])
    @establishment.with_lock { @establishment.update!(establishment_params) }
    redirect_to admin_establishments_path, notice: 'Contrato atualizado.', status: :see_other
  rescue ActiveRecord::RecordInvalid
    render :edit, status: :unprocessable_entity
  end
  private
  def require_platform_admin
    head :forbidden unless current_user&.platform_admin?
  end
  def establishment_params
    params.require(:establishment).permit(:name, :slug, :table_limit, :monthly_fee, :active)
  end
end
