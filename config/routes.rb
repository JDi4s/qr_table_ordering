Rails.application.routes.draw do
  mount ActionCable.server => "/cable"

  # Auth
  get "login",  to: "sessions#new"
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"

  # Customer (QR access)
  resources :tables, only: [] do
    resources :orders, only: [:new, :create] do
      collection { get :my }
    end
  end

  # Staff
  namespace :staff do
    # ✅ Combined menu hub
    get "menu", to: "menu#index", as: :menu

    resources :orders, only: [:index, :show, :update] do
      collection do
        get :history
        delete :clear_history
      end
    end

    resources :tables, only: [:index] do
      member { get :qr_code }
    end

    resources :categories, except: [:index, :show] do
      member { patch :toggle_availability }
    end

    resources :menu_items, except: [:index, :show] do
      member { patch :toggle_availability }
    end

    resources :order_items, only: [:update]
    resource :settings, only: [:edit, :update]
  end

  get "up" => "rails/health#show", as: :rails_health_check
  root "sessions#new"
end
