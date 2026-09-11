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
        get :review
        post :review
      end
      member do
        post :cancel
      end
    end
  end
  namespace :staff do
    resources :orders, only: [:index, :show, :update] do
      member { patch :mark_paid; patch :pay_item; patch :pay_selected }
      collection { get :history }
    end
    resources :order_items, only: :update
    resources :service_calls, only: :update
    resources :tables, only: [:index, :show, :create, :update, :destroy] do
      collection { get :active }
      member { get :qr_code }
    end
    resources :users, only: [:index, :create, :update, :destroy]
    get '/menu', to: 'menu#index', as: :menu
    resources :menu_items do
      collection do
        delete :purge_archived
        delete :purge_uncategorized
      end
      member do
        patch :toggle_availability
        patch :restore
        delete :purge
      end
    end
    resources :categories do
      member do
        patch :toggle_availability
        patch :restore
        delete :purge
      end
    end
    resource :push_subscription, only: [:create, :destroy], controller: 'push_subscriptions'
    resource :settings, only: [:edit, :update]
    resources :reports, only: [:index] do
      collection { get :export; get :pdf; post :close }
    end
    resources :audit_events, only: [:index]
  end
  root 'sessions#new'
end
