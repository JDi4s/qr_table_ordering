class StaffPushSubscription < ApplicationRecord
  belongs_to :user

  validates :endpoint, :p256dh, :auth, presence: true
  validates :endpoint, uniqueness: true

  def self.register_for!(user, attributes)
    user.with_lock do
      where(endpoint: attributes[:endpoint]).where.not(user_id: user.id).destroy_all
      subscription = user.staff_push_subscriptions.find_or_initialize_by(endpoint: attributes[:endpoint])
      subscription.assign_attributes(attributes)
      subscription.save!
      subscription
    end
  end
end
