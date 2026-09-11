class SupportTicket < ApplicationRecord
  STATUSES = %w[open in_analysis waiting_establishment resolved].freeze
  CATEGORIES = %w[orders menu tables team reports billing other].freeze
  PRIORITIES = %w[normal urgent].freeze

  belongs_to :establishment
  belongs_to :created_by, class_name: 'User', inverse_of: :created_support_tickets
  belongs_to :assigned_to, class_name: 'User', optional: true
  has_many :messages, -> { order(:created_at) }, class_name: 'SupportTicketMessage', dependent: :destroy
  has_many :support_sessions, dependent: :restrict_with_error

  validates :subject, presence: true, length: { maximum: 140 }
  validates :status, inclusion: { in: STATUSES }
  validates :category, inclusion: { in: CATEGORIES }
  validates :priority, inclusion: { in: PRIORITIES }
  validate :creator_belongs_to_establishment, on: :create
  validate :assignee_is_platform_admin

  scope :unresolved, -> { where.not(status: 'resolved') }
  scope :recent_first, -> { order(updated_at: :desc) }

  def resolved?
    status == 'resolved'
  end

  private

  def creator_belongs_to_establishment
    return if created_by&.establishment_id == establishment_id && created_by&.manager?

    errors.add(:created_by, 'tem de ser um gerente do estabelecimento')
  end

  def assignee_is_platform_admin
    return if assigned_to.blank? || assigned_to.platform_admin?

    errors.add(:assigned_to, 'tem de pertencer ao suporte da plataforma')
  end
end
