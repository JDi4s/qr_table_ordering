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
    get 'categories/index'
    get 'categories/show'
    get 'categories/new'
    get 'categories/edit'
    get 'menu_items/index'
    get 'menu_items/show'
    get 'menu_items/new'
    get 'menu_items/edit'
    resources :orders, only: [:index, :show, :update]
    resources :tables, only: [:index] do
      member do
        get :qr_code
      end
    end
  end

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # Root redirects to staff dashboard
  root "staff/orders#index"
end
