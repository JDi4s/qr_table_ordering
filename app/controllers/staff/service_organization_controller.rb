class Staff::ServiceOrganizationController < Staff::BaseController
  before_action :require_manager

  def edit
    @areas = current_establishment.production_areas.order(:position, :name)
    @zones = current_establishment.service_zones.order(:name)
  end

  def update
    CustomerMenuBroadcast.batch do
      current_establishment.with_lock do
        case params[:operation]
        when 'division'
          enabled = params[:enabled] == '1'
          raise Order::InvalidTransition, 'A Administração tem de autorizar a divisão por áreas.' if enabled && !current_establishment.production_areas_enabled?
          if !enabled && current_establishment.orders.where(status: 'accepted').joins(:preparation_tasks).exists?
            raise Order::InvalidTransition, 'Conclui os pedidos em preparação antes de desligar a divisão.'
          end
          current_establishment.update!(service_division_enabled: enabled)
          current_establishment.ensure_default_production_areas! if enabled
          raise Order::InvalidTransition, 'Cria ou ativa pelo menos uma área antes de ligar a divisão.' if enabled && current_establishment.available_production_areas.empty?
          if enabled
            current_establishment.orders.where(status: 'accepted', voided_at: nil).find_each do |order|
              order.with_lock { PreparationTask.build_for!(order); order.touch }
            end
          end
        when 'area'
          raise Order::InvalidTransition, 'A Administração tem de autorizar a divisão por áreas.' unless current_establishment.production_areas_enabled?
          area = params[:area_id].present? ? current_establishment.production_areas.find(params[:area_id]) : current_establishment.production_areas.new
          area.assign_attributes(params.require(:area).permit(:name, :preparation_key, :active))
          if !area.active? && area.preparation_tasks.where(state: %w[preparing ready]).joins(:order).where(orders: { status: 'accepted', voided_at: nil }).exists?
            raise Order::InvalidTransition, 'Este posto ainda tem preparação em curso.'
          end
          if area.active? && (area.new_record? || area.active_changed?) && current_establishment.production_areas.where(active: true).where.not(id: area.id).count >= current_establishment.production_areas_limit
            raise Order::InvalidTransition, 'Atingiste o limite de áreas autorizado pela Administração.'
          end
          area.save!
        when 'zone'
          zone = params[:zone_id].present? ? current_establishment.service_zones.find(params[:zone_id]) : current_establishment.service_zones.new
          zone.name = params.dig(:zone, :name)
          zone.routing = params.require(:zone).permit(routing: MenuItem::PREPARATION_KEYS.keys).fetch(:routing, {}).to_h.reject { |_, id| id.blank? }
          zone.save!
        when 'tables'
          zone = current_establishment.service_zones.find(params[:zone_id])
          first, last = Integer(params[:first], exception: false), Integer(params[:last], exception: false)
          raise Order::InvalidTransition, 'Indica um intervalo válido de mesas.' unless first && last && first > 0 && last >= first
          tables = current_establishment.tables.where(deleted_at: nil, number: first..last)
          tables.each { |table| table.update!(service_zone: zone) }
        else
          raise Order::InvalidTransition, 'Operação inválida.'
        end
        AuditLogger.record(user: current_user, action: 'service_organization_updated', record: current_establishment, metadata: { operation: params[:operation] })
      end
    end
    redirect_to edit_staff_service_organization_path, notice: 'Organização do serviço guardada.', status: :see_other
  rescue ActiveRecord::RecordInvalid => error
    redirect_to edit_staff_service_organization_path, alert: error.record.errors.full_messages.join('. '), status: :see_other
  end
end
