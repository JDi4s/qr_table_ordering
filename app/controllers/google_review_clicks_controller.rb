class GoogleReviewClicksController < ApplicationController
  def create
    table = Table.joins(:establishment).where(active: true, deleted_at: nil, establishments: { active: true })
      .find_by!(qr_token: params[:table_id])
    venue = table.establishment
    token = session[:customer_token]
    unless venue.google_reviews_available? && token.present? &&
           table.orders.not_voided.where(customer_token: token).where.not(status: 'denied').exists?
      head :not_found
      return
    end

    GoogleReviewClick.record!(venue, token)
    response.headers['Cache-Control'] = 'no-store, private'
    redirect_to venue.google_review_url, allow_other_host: true, status: :see_other
  end
end
