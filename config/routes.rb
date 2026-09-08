Rails.application.routes.draw do
  mount ActionCable.server => '/cable'
  get 'up', to: 'rails/health#show'
  get 'login', to: 'sessions#new'
  post 'login', to: 'sessions#create'
  delete 'logout', to: 'sessions#destroy'
  namespace :admin do
    resources :establishments, except: [:show, :destroy]
  end
  resources :tables, only: [] do
    resources :service_calls, only: :create
    resources :orders, only: [:new, :create] do
      collection do
        get :my
        post :review
      end
      member do
        post :accept_remaining
        post :cancel
      end
    end
  end
  namespace :staff do
    resources :orders, only: [:index, :show, :update] do
      collection { get :history }
    end
    resources :order_items, only: :update
    resources :service_calls, only: :update
    resources :tables, only: [:index, :create, :update] do
      member { get :qr_code }
    end
    resources :users, only: [:index, :create, :update]
    get '/menu', to: 'menu#index', as: :menu
    resources :menu_items do
      member { patch :toggle_availability }
    end
    resources :categories do
      member { patch :toggle_availability }
    end
    resource :settings, only: [:edit, :update]
  end
  root 'sessions#new'
end
