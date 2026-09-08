class Table < ApplicationRecord
  belongs_to :establishment
  has_many :orders, dependent: :restrict_with_error
  has_many :service_calls, dependent: :restrict_with_error
  before_validation :generate_qr_token, on: :create
  around_save :enforce_capacity
  validates :number, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :establishment_id }
  validates :qr_token, presence: true, uniqueness: true

  def to_param
    qr_token
  end

  def ordering_url
    URI.join(Rails.configuration.x.public_url + '/', Rails.application.routes.url_helpers.new_table_order_path(qr_token)).to_s
  end

  def qr_code
    RQRCode::QRCode.new(ordering_url).as_svg(module_size: 6, standalone: true, offset: 24)
  end

  private

  def generate_qr_token
    self.qr_token ||= SecureRandom.hex(24)
  end

  def enforce_capacity
    establishment.with_lock do
      if active? && (new_record? || will_save_change_to_active?)
        if !establishment.active? || establishment.tables.where(active: true).where.not(id: id).count >= establishment.table_limit
          errors.add(:base, 'Limite de mesas atingido ou estabelecimento suspenso. Contacte o administrador.')
          raise ActiveRecord::RecordInvalid, self
        end
      end
      yield
    end
  end
end
