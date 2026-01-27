class Table < ApplicationRecord
  before_create :generate_qr_token

  private

  def generate_qr_token
    self.qr_token = SecureRandom.hex(5) if qr_token.blank?
  end
end
