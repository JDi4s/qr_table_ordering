Rails.application.routes.draw do
  mount ActionCable.server => "/cable"

  get "login",  to: "sessions#new"
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"

  # Customer (QR)
  resources :tables, only: [] do
    resources :orders, only: [:new, :create] do
      collection do
        get :my
        post :review
      end

      member do
        patch :accept_remaining
        patch :cancel
      end
    end
  end

  # Staff
  namespace :staff do
    resources :orders, only: [:index, :show, :update] do
      collection do
        get :history
        delete :clear_history
      end
    end

    resources :tables, only: [:index] do
      member { get :qr_code }
    end

    get "menu", to: "menu#index", as: :menu

    resources :menu_items do
      member { patch :toggle_availability }
    end

    resources :categories do
      member { patch :toggle_availability }
    end

    resources :order_items, only: [:update]
    resource :settings, only: [:edit, :update]
  end

  root "sessions#new"
end
