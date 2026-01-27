Rails.application.routes.draw do
  get 'sessions/new'
  get 'sessions/create'
  get 'sessions/destroy'
  # Orders nested under tables (via QR token)
  resources :tables, only: [] do
    resources :orders, only: [:new, :create, :show]
  end
  get 'login', to: 'sessions#new'
  post 'login', to: 'sessions#create'
  delete 'logout', to: 'sessions#destroy'

  namespace :staff do
    get 'orders/index'
    get 'orders/show'
    get 'orders/update'
    resources :orders, only: [:index, :show, :update]
  end


  # Health check route
  get "up" => "rails/health#show", as: :rails_health_check

  # Optional: a simple root page
  root "home#index"
end
