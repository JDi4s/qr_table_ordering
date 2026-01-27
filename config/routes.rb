Rails.application.routes.draw do
  # Orders nested under tables (via QR token)
  resources :tables, only: [] do
    resources :orders, only: [:new, :create, :show]
  end

  # Health check route
  get "up" => "rails/health#show", as: :rails_health_check

  # Optional: a simple root page
  root "home#index"
end
