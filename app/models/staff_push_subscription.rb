class StaffPushSubscription < ApplicationRecord
  belongs_to :user

  validates :endpoint, :p256dh, :auth, presence: true
  validates :user_id, uniqueness: true
  validates :endpoint, uniqueness: true
  validate :user_has_only_one_subscription

  private

  def user_has_only_one_subscription
    return if user.blank?

    return if StaffPushSubscription.where(user_id: user.id).where.not(id: id).exists?

    existing = user.staff_push_subscription
    return if existing.blank? || existing == self

    errors.add(:user_id, 'já tem um dispositivo associado')
  end
end
