class Staff::AuditEventsController < Staff::BaseController
  before_action :require_manager

  def index
    @events = current_establishment.audit_events.includes(:user, :auditable).recent_first.limit(300)
  end
end
