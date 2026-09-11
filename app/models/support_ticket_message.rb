class SupportTicketMessage < ApplicationRecord
  belongs_to :support_ticket, touch: true
  belongs_to :author, class_name: 'User', inverse_of: :support_ticket_messages
  has_one_attached :attachment

  validates :body, length: { maximum: 5_000 }, allow_blank: true
  validate :body_or_attachment
  validate :attachment_is_safe

  def from_support?
    author&.platform_admin? || false
  end

  private

  def body_or_attachment
    errors.add(:base, 'Escreve uma mensagem ou anexa uma imagem.') if body.blank? && !attachment.attached?
  end

  def attachment_is_safe
    return unless attachment.attached?

    errors.add(:attachment, 'deve ser PNG, JPG ou WebP') unless attachment.content_type.in?(%w[image/png image/jpeg image/webp])
    errors.add(:attachment, 'não pode ultrapassar 5 MB') if attachment.byte_size > 5.megabytes
  end
end
