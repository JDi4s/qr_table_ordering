class Table < ApplicationRecord
  has_many :orders, dependent: :destroy
  before_create :generate_qr_token
  validates :number, presence: true, uniqueness: true
  validates :qr_token, uniqueness: true


  # Use QR token in URLs instead of numeric ID
  def to_param
    qr_token
  end

  def qr_code
    require 'rqrcode'
    url = Rails.application.routes.url_helpers.new_table_order_url(self.qr_token, host: "localhost:3000")
    qrcode = RQRCode::QRCode.new(url)
    qrcode.as_svg(
    offset: 0,
    color: '000',
    shape_rendering: 'crispEdges',
    module_size: 6,
    standalone: true
    )
  end

  private

  def generate_qr_token
    self.qr_token = SecureRandom.hex(5) if qr_token.blank?
  end
end
