class CashClosure < ApplicationRecord
  belongs_to :establishment
  belongs_to :user
  belongs_to :reopened_by_user, class_name: 'User', optional: true

  scope :active, -> { where(reopened_at: nil) }

  validates :business_date, presence: true,
                            uniqueness: { scope: :establishment_id, conditions: -> { where(reopened_at: nil) } }
  validates :total_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :reopen_reason, presence: true, length: { maximum: 300 }, if: :reopened?

  def reopened?
    reopened_at.present?
  end

  def reopen!(actor, reason:)
    reason = reason.to_s.strip
    raise Order::InvalidTransition, 'Indique o motivo para reabrir o Caixa.' if reason.blank?
    raise Order::InvalidTransition, 'O motivo não pode ultrapassar 300 caracteres.' if reason.length > 300
    unless actor&.manager? && actor.establishment_id == establishment_id
      raise Order::InvalidTransition, 'Apenas um gerente deste estabelecimento pode reabrir o Caixa.'
    end

    establishment.with_lock do
      with_lock do
        raise Order::InvalidTransition, 'Este Caixa já foi reaberto.' if reopened?
        update!(reopened_at: Time.current, reopened_by_user: actor, reopen_reason: reason)
      end
    end
  end
end
