class Admin::AuditEventsController < Admin::BaseController
  def index
    @establishments = Establishment.order(:name)
    @establishment = @establishments.find_by(id: params[:establishment_id])
    scope = AuditEvent.includes(:establishment, :user, :auditable).recent_first
    scope = scope.where(establishment: @establishment) if @establishment
    @events = scope.limit(500)
  end
end
