class Staff::TablesController < Staff::BaseController
  before_action :require_manager, except: [:index, :qr_code]

  def index
    @tables = current_establishment.tables.order(:number)
    @table = current_establishment.tables.new
  end

  def create
    current_establishment.tables.create!(params.require(:table).permit(:number))
    redirect_to staff_tables_path, notice: 'Mesa criada.', status: :see_other
  end

  def update
    table = current_establishment.tables.find_by!(qr_token: params[:id])
    table.update!(params.require(:table).permit(:number, :active))
    redirect_to staff_tables_path, notice: 'Mesa atualizada.', status: :see_other
  end

  def qr_code
    table = current_establishment.tables.where(active: true).find_by!(qr_token: params[:id])
    png = RQRCode::QRCode.new(table.ordering_url).as_png(size: 480, border_modules: 4)
    send_data png.to_s, type: 'image/png', disposition: 'attachment', filename: "mesa_#{table.number}_qr.png"
  end
end
