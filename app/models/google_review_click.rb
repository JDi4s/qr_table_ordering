class GoogleReviewClick < ApplicationRecord
  belongs_to :establishment
  validates :visitor_digest, format: { with: /\A[0-9a-f]{64}\z/ }

  def self.record!(establishment, customer_token)
    create!(establishment: establishment,
            visitor_digest: Digest::SHA256.hexdigest("#{establishment.id}:#{customer_token}"))
  end
end
