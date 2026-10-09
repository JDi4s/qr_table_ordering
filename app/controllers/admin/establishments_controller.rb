class Admin::EstablishmentsController < Admin::BaseController
  def index
    @establishments = Establishment.where(deleted_at: nil).includes(:tables, :support_tickets).order(:name)
    @open_tickets_count = SupportTicket.unresolved.count
    @new_landing_requests_count = LandingRequest.where(status: 'new').count
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
    @establishment = Establishment.where(deleted_at: nil).find(params[:id])
  end
  def update
    @establishment = Establishment.where(deleted_at: nil).find(params[:id])
    @establishment.with_lock do
      @establishment.update!(establishment_params)
      @establishment.ensure_default_production_areas! if @establishment.production_areas_limit.to_i.positive?
    end
    AuditLogger.record(user: current_user, action: 'establishment_contract_updated', record: @establishment,
                       metadata: { plan: @establishment.plan, table_limit: @establishment.table_limit,
                                   production_areas_limit: @establishment.production_areas_limit,
                                   google_reviews_enabled: @establishment.google_reviews_enabled? })
    redirect_to admin_establishments_path, notice: 'Contrato atualizado.', status: :see_other
  rescue ActiveRecord::RecordInvalid
    render :edit, status: :unprocessable_entity
  end
  def destroy
    venue = Establishment.where(deleted_at: nil).find(params[:id])
    venue.with_lock do
      if venue.orders.unpaid.exists? || venue.service_calls.where.not(status: 'resolved').exists?
        raise Order::InvalidTransition, 'Conclui os pedidos, pagamentos e chamadas antes de eliminar.'
      end
      venue.update!(active: false, accepting_orders: false, deleted_at: Time.current)
      venue.users.update_all(active: false, updated_at: Time.current)
      venue.tables.update_all(active: false, updated_at: Time.current)
      venue.support_sessions.where(ended_at: nil).each(&:finish!)
      AuditLogger.record(user: current_user, action: 'establishment_deleted', record: venue, metadata: { name: venue.name, history_preserved: true })
    end
    redirect_to admin_establishments_path, notice: 'Estabelecimento eliminado da gestão. Acessos bloqueados e histórico preservado.', status: :see_other
  end

  private
  def establishment_params
    params.require(:establishment).permit(:name, :slug, :table_limit, :monthly_fee, :active, :production_areas_limit, :plan, :google_reviews_enabled)
  end
end
