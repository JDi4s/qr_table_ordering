class Staff::TableVisitsController < Staff::BaseController
  def index
    # Do not let an old poll restore a session after logout/account changes.
    request.session_options[:skip] = true
    tables = current_establishment.tables.where(active: true, deleted_at: nil)
      .includes(:current_table_visit).order(:number)
    pending = tables.filter_map { |table| table.current_table_visit if table.current_table_visit&.waiting? }
    response.headers['Cache-Control'] = 'no-store, private'
    render json: { pending_ids: pending.map(&:id), states: tables.map { |table| [table.id, table.current_table_visit&.id, table.current_table_visit&.state] },
                   html: render_to_string(partial: 'staff/table_visits/list', formats: [:html], locals: { tables: tables }) }
  end

  def create
    table = current_establishment.tables.find_by!(qr_token: params[:table_id], active: true, deleted_at: nil)
    visit = TableVisit.activate_for!(table)
    AuditLogger.record(user: current_user, action: 'table_visit_opened', record: table, metadata: { visit_id: visit.id })
    redirect_to staff_orders_path, notice: "Mesa #{table.number} ativada. Os clientes já podem pedir.", status: :see_other
  end

  def destroy
    table = current_establishment.tables.find_by!(qr_token: params[:table_id], active: true, deleted_at: nil)
    visit = TableVisit.close_for!(table)
    AuditLogger.record(user: current_user, action: 'table_visit_closed', record: table, metadata: { visit_id: visit&.id })
    redirect_to staff_orders_path, notice: "Visita da Mesa #{table.number} encerrada.", status: :see_other
  end
end
