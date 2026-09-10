class AuditLogger
  def self.record(user:, action:, record: nil, metadata: {})
    establishment = record.respond_to?(:establishment) ? record.establishment : user&.establishment
    establishment ||= record&.table&.establishment if record.respond_to?(:table)
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
