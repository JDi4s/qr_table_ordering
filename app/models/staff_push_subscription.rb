class StaffPushSubscription < ApplicationRecord
  belongs_to :user

  validates :endpoint, :p256dh, :auth, presence: true
  validates :user_id, uniqueness: true
  validates :endpoint, uniqueness: true
end
