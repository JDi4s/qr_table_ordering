class SupportSession < ApplicationRecord
  belongs_to :platform_admin, class_name: 'User'
  belongs_to :establishment
  belongs_to :support_ticket, optional: true

  validates :started_at, :expires_at, presence: true
  validate :administrator_is_platform_admin
  validate :ticket_matches_establishment
  validate :reason_or_ticket

  scope :active, -> { where(ended_at: nil).where('expires_at > ?', Time.current) }

  def active?
    ended_at.nil? && expires_at.future?
  end

  def finish!
    update!(ended_at: Time.current) unless ended_at?
  end

  private

  def administrator_is_platform_admin
    errors.add(:platform_admin, 'inválido') unless platform_admin&.platform_admin?
  end

  def ticket_matches_establishment
    return if support_ticket.blank? || support_ticket.establishment_id == establishment_id

    errors.add(:support_ticket, 'não pertence a este estabelecimento')
  end

  def reason_or_ticket
    errors.add(:reason, 'é obrigatório sem um ticket associado') if support_ticket.blank? && reason.blank?
  end
end
