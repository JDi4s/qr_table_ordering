class Staff::TablesController < ApplicationController
  before_action :require_login

  def index
    @tables = Table.all
  end

  def qr_code
    table = Table.find(params[:id])
    require 'rqrcode'
    require 'chunky_png'

    qrcode = RQRCode::QRCode.new(
      Rails.application.routes.url_helpers.new_table_order_url(table.qr_token, host: "localhost:3000")
    )

    png = qrcode.as_png(
      bit_depth: 1,
      border_modules: 4,
      color_mode: ChunkyPNG::COLOR_GRAYSCALE,
      color: "black",
      file: nil,
      fill: "white",
      module_px_size: 6,
      size: 240
    )

    send_data png.to_s, type: 'image/png', disposition: 'attachment', filename: "table_#{table.number}_qr.png"
  end

  private

  def require_login
    redirect_to login_path, alert: "Please log in as staff" unless current_user&.staff?
  end

  def current_user
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  end
end
