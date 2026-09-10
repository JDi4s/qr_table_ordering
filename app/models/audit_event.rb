class AuditEvent < ApplicationRecord
  belongs_to :establishment
  belongs_to :user, optional: true
  belongs_to :auditable, polymorphic: true, optional: true

  validates :action, presence: true

  scope :recent_first, -> { order(created_at: :desc) }
end
