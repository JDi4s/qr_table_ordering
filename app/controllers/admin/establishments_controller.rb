class Admin::EstablishmentsController < Admin::BaseController
  def index
    @establishments = Establishment.includes(:tables, :support_tickets).order(:name)
    @open_tickets_count = SupportTicket.unresolved.count
    @active_clients_count = @establishments.count(&:active?)
    @active_support_sessions = SupportSession.active.includes(:establishment, :platform_admin).order(started_at: :desc)
  end
  def new
    @establishment = Establishment.new
  end
  def create
    @establishment = Establishment.new(establishment_params)
    Establishment.transaction do
      @establishment.save!
      @establishment.ensure_default_production_areas! if @establishment.production_areas_limit.to_i.positive?
      @establishment.users.create!(params.require(:manager).permit(:name, :email, :password).merge(role: 'manager'))
    end
    AuditLogger.record(user: current_user, action: 'establishment_created', record: @establishment)
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
    @establishment.with_lock do
      @establishment.update!(establishment_params)
      @establishment.ensure_default_production_areas! if @establishment.production_areas_limit.to_i.positive?
    end
    AuditLogger.record(user: current_user, action: 'establishment_contract_updated', record: @establishment,
                       metadata: { plan: @establishment.plan, table_limit: @establishment.table_limit,
                                   production_areas_limit: @establishment.production_areas_limit })
    redirect_to admin_establishments_path, notice: 'Contrato atualizado.', status: :see_other
  rescue ActiveRecord::RecordInvalid
    render :edit, status: :unprocessable_entity
  end
  private
  def establishment_params
    params.require(:establishment).permit(:name, :slug, :table_limit, :monthly_fee, :active, :production_areas_limit, :plan)
  end
end
