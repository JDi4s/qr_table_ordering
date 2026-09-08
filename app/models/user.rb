class User < ApplicationRecord
  has_secure_password
  belongs_to :establishment, optional: true
  enum role: { staff: 'staff', manager: 'manager', platform_admin: 'platform_admin' }
  before_validation { self.email = email.to_s.strip.downcase }
  validates :email, presence: true, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, presence: true
  validates :password, length: { minimum: 12 }, if: -> { new_record? || password.present? }
  validates :establishment, presence: true, unless: :platform_admin?
  validate { errors.add(:establishment, 'deve estar vazio para o administrador da plataforma') if platform_admin? && establishment_id.present? }

  def venue_access?
    active? && !platform_admin? && establishment&.active?
  end
end
