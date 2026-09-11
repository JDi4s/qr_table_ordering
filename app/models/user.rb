class User < ApplicationRecord
  has_secure_password
  belongs_to :establishment, optional: true
  has_one :staff_push_subscription, dependent: :destroy
  has_many :payments, dependent: :restrict_with_error
  has_many :audit_events, dependent: :nullify
  has_many :production_area_users, dependent: :destroy
  has_many :production_areas, through: :production_area_users
  enum role: { staff: 'staff', manager: 'manager', platform_admin: 'platform_admin' }
  before_validation do
    self.email = email.to_s.strip.downcase.presence
    self.username = username.to_s.strip.downcase.presence
    if username.blank? && email.present?
      base = email.split('@').first.gsub(/[^a-z0-9]+/i, '_').downcase.gsub(/\A_|_\z/, '').presence || 'utilizador'
      self.username = "#{base.first(24)}_#{SecureRandom.hex(3)}"
    end
  end
  validates :email, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :email, presence: true, if: -> { manager? || platform_admin? }
  validates :username, presence: true, if: :staff?
  validates :username, format: { with: /\A[a-z0-9][a-z0-9_.-]{2,30}\z/, message: 'deve ter 3 a 31 caracteres sem espaços' }, allow_blank: true
  validates :username, uniqueness: { case_sensitive: false }, allow_blank: true
  validates :role, presence: true
  validates :password, length: { minimum: 12 }, if: -> { new_record? || password.present? }
  validates :establishment, presence: true, unless: :platform_admin?
  validate { errors.add(:establishment, 'deve estar vazio para o administrador da plataforma') if platform_admin? && establishment_id.present? }

  def venue_access?
    active? && !platform_admin? && establishment&.active?
  end

  def login_identifier
    username.presence || email
  end

  def staff_account?
    staff? || manager?
  end

  def removable_from_team?
    persisted? &&
      !payments.exists? &&
      !audit_events.exists? &&
      !Order.where(paid_by_user_id: id).exists? &&
      !ServiceCall.where(assigned_user_id: id).exists? &&
      !CashClosure.where(user_id: id).exists?
  end
end
