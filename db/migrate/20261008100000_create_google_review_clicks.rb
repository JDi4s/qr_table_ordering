class CreateGoogleReviewClicks < ActiveRecord::Migration[7.1]
  def change
    add_column :establishments, :google_review_tracking_started_at, :datetime,
               null: false, default: -> { 'CURRENT_TIMESTAMP' }
    create_table :google_review_clicks do |t|
      t.references :establishment, null: false, foreign_key: true, index: false
      t.string :visitor_digest, null: false, limit: 64
      t.datetime :created_at, null: false
    end
    add_index :google_review_clicks, [:establishment_id, :created_at, :visitor_digest], name: 'index_review_clicks_on_venue_date_visitor'
  end
end
