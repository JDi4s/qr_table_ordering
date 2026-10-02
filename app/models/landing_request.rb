class LandingRequest < ApplicationRecord
  STATUSES = %w[new contacted closed].freeze
  BUSINESS_TYPES = {
    'cafe' => 'Café', 'restaurant' => 'Restaurante', 'bar' => 'Bar',
    'pastry' => 'Pastelaria', 'other' => 'Outro'
  }.freeze

  validates :first_name, :last_name, :region, presence: true, length: { maximum: 100 }
  validates :business_email, presence: true, length: { maximum: 254 },
                             format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :phone, presence: true, length: { maximum: 30 },
                    format: { with: /\A\+?[\d\s().-]{7,30}\z/ }
  validates :business_type, inclusion: { in: BUSINESS_TYPES.keys }
  validates :status, inclusion: { in: STATUSES }

  scope :recent_first, -> { order(created_at: :desc) }
end
