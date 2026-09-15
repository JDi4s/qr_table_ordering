class AddGoogleReviewsToEstablishments < ActiveRecord::Migration[7.1]
  def change
    add_column :establishments, :google_reviews_enabled, :boolean, default: false, null: false
    add_column :establishments, :google_review_url, :string
  end
end
