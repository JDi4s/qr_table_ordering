Rails.application.routes.draw do
  get 'home/index'
  get 'tables/index'
  # Sessions (login/logout)
  get 'login', to: 'sessions#new'
  post 'login', to: 'sessions#create'
  delete 'logout', to: 'sessions#destroy'

   # shows QR codes for all tables
  resources :tables, only: [:index]


  # Orders nested under tables (via QR token)
  resources :tables, only: [] do
    resources :orders, only: [:new, :create, :show]
  end

  # Staff namespace
  namespace :staff do
    resources :orders, only: [:index, :show, :update]
  end

  # Health check route
  get "up" => "rails/health#show", as: :rails_health_check

  # Root page
  root "home#index"
end
