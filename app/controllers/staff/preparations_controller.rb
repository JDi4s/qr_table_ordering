class Staff::PreparationsController < Staff::BaseController
  def index
    @areas = current_user.preparation_staff? ? current_user.production_areas.where(active: true) : current_establishment.available_production_areas
    @area_id = params[:area_id].to_i
    @area_id = @areas.first&.id if current_user.preparation_staff? && @area_id.positive? && !@areas.exists?(id: @area_id)
    scope = current_establishment.orders.where(status: 'accepted', voided_at: nil)
    @tasks = PreparationTask.joins(:order_item).where(order_items: { order_id: scope.select(:id) }).where.not(state: %w[delivered cancelled])
    @tasks = @tasks.where(production_area_id: @areas.select(:id)) if current_user.preparation_staff?
    @tasks = @tasks.where(production_area_id: @area_id) if @area_id.present? && @area_id.positive?
    @tasks = @tasks.includes(:production_area, order_item: { order: :table }).order(:created_at, :id).to_a
    @groups = @tasks.group_by(&:order)
    render layout: false if request.headers['Turbo-Frame'].present?
  end

  def update
    task = PreparationTask.joins(order_item: { order: :table }).where(tables: { establishment_id: current_establishment.id }).find(params[:id])
    if current_user.preparation_staff? && !current_user.production_areas.where(active: true).exists?(id: task.production_area_id)
      head :forbidden
      return
    end
    changed = task.state != params[:state].to_s
    task.transition!(params[:state].to_s, current_user)
    PreparationNotifier.ready(task) if changed && task.state == 'ready'
    AuditLogger.record(user: current_user, action: 'preparation_updated', record: task.order, metadata: { task_id: task.id, state: task.state, area_id: task.production_area_id })
    redirect_to staff_preparations_path(area_id: params[:area_id]), status: :see_other
  end
end

