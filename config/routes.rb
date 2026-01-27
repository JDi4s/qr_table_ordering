Rails.application.routes.draw do
  # Staff login/logout
  get 'login', to: 'sessions#new'
  post 'login', to: 'sessions#create'
  delete 'logout', to: 'sessions#destroy'

  # Customers access menu/orders via table QR code
  resources :tables, only: [] do
    resources :orders, only: [:new, :create, :show]
  end

  # Staff namespace
  namespace :staff do
    get 'tables/index'
    resources :orders, only: [:index, :show, :update] # staff dashboard
    resources :tables, only: [:index] # list of tables + QR codes
  end

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # Root redirects to staff dashboard (optional)
  root "staff/orders#index"
end
