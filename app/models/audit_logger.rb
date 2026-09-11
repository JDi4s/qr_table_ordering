class AuditLogger
  def self.record(user:, action:, record: nil, metadata: {})
    establishment = record.respond_to?(:establishment) ? record.establishment : user&.establishment
    establishment ||= record&.table&.establishment if record.respond_to?(:table)
    if establishment.blank? && user&.platform_admin?
      establishment = SupportSession.active.where(platform_admin_id: user.id).order(started_at: :desc).first&.establishment
    end
    return unless establishment

    AuditEvent.create!(
      establishment: establishment,
      user: user,
      action: action,
      auditable: record,
      metadata: metadata.stringify_keys
    )
  rescue ActiveRecord::RecordInvalid
    Rails.logger.warn("Não foi possível registar auditoria: #{action}")
  end
end
