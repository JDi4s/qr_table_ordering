class Staff::TablesController < Staff::BaseController
  before_action :require_manager, except: [:index, :active, :show, :qr_code]

  def index
    @tables = current_establishment.tables.where(deleted_at: nil).order(:number)
    @tables_with_consumption_count = current_establishment.tables.where(deleted_at: nil).joins(:orders).merge(Order.unpaid).distinct.count
    @table = current_establishment.tables.new
  end

  def active
    @tables = current_establishment.tables.where(deleted_at: nil)
      .joins(:orders)
      .merge(Order.unpaid)
      .distinct
      .includes(orders: [{ order_items: :menu_item }, { payments: :user }])
      .order(:number)
  end

  def show
    @table = current_establishment.tables.where(deleted_at: nil).find_by!(qr_token: params[:id])
    @orders = @table.orders
      .unpaid
      .includes(order_items: :menu_item, payments: :user)
      .order(:created_at)
  end

  def create
    table = current_establishment.tables.create!(params.require(:table).permit(:number))
    AuditLogger.record(user: current_user, action: 'table_created', record: table)
    redirect_to staff_tables_path, notice: 'Mesa criada.', status: :see_other
  end

  def update
    table = current_establishment.tables.where(deleted_at: nil).find_by!(qr_token: params[:id])
    table.update!(params.require(:table).permit(:number, :active))
    AuditLogger.record(user: current_user, action: 'table_updated', record: table)
    redirect_to staff_tables_path, notice: 'Mesa atualizada.', status: :see_other
  end

  def destroy
    table = current_establishment.tables.where(deleted_at: nil).find_by!(qr_token: params[:id])
    raise Order::InvalidTransition, 'Esta mesa tem pedidos ou chamadas em curso. Conclua-os antes de eliminar.' if table.involved_in_open_service?

    metadata = { deleted_table_id: table.id, number: table.number }
    Table.transaction do
      table.update!(active: false, deleted_at: Time.current)
      AuditLogger.record(user: current_user, action: 'table_deleted', metadata: metadata)
    end

    redirect_to staff_tables_path, notice: "Mesa #{metadata[:number]} eliminada.", status: :see_other
  end

  def qr_code
    table = current_establishment.tables.where(active: true, deleted_at: nil).find_by!(qr_token: params[:id])

    unless params[:download].present? || params[:format].to_s == 'png'
      @table = table
      render :qr_code
      return
    end

    png = RQRCode::QRCode.new(table.ordering_url).as_png(size: 480, border_modules: 4)
    disposition = params[:download].present? ? 'attachment' : 'inline'
    send_data png.to_s, type: 'image/png', disposition: disposition, filename: "mesa_#{table.number}_qr.png"
  end
end
