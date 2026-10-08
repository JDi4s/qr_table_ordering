Rails.application.routes.draw do
  mount ActionCable.server => '/cable'
  get 'up', to: 'rails/health#show'
  get 'login', to: 'sessions#new'
  post 'login', to: 'sessions#create'
  post 'landing_requests', to: 'landing_requests#create'
  delete 'logout', to: 'sessions#destroy'
  namespace :admin do
    resources :landing_requests, only: [:index, :show, :update]
    resources :establishments, except: [:show, :destroy] do
      resource :menu_import, only: [:new, :create], controller: 'menu_imports' do
        post :review
        post :selection, to: 'menu_imports#new'
      end
    end
    resources :support_tickets, only: [:index, :show, :update] do
      resources :messages, only: :create, controller: 'support_ticket_messages'
    end
    resources :audit_events, only: :index
    resources :support_sessions, only: [:create, :destroy]
    resource :push_subscription, only: [:create, :destroy], controller: 'push_subscriptions'
  end
  resources :tables, only: [] do
    get :access_status, to: 'orders#access_status'
    get :menu_snapshot, to: 'orders#menu_snapshot'
    resources :google_review_clicks, only: :create
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
    resource :lunch_menu, only: [:edit, :update]
    resources :orders, only: [:index, :show, :update] do
      member { patch :mark_paid; patch :pay_item; patch :pay_selected }
      collection { get :history }
    end
    resources :order_items, only: :update
    resources :service_calls, only: :update
    resources :tables, only: [:index, :show, :create, :update, :destroy] do
      resource :visit, only: [:create, :destroy], controller: 'table_visits'
      collection { get :active }
      member { get :qr_code }
    end
    resources :table_visits, only: :index
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
    resource :settings, only: [:edit, :update] do
      patch :service_status
    end
    resources :payments, only: [] do
      member { patch :void }
    end
    resources :support_tickets, only: [:index, :new, :create, :show] do
      resources :messages, only: :create, controller: 'support_ticket_messages'
    end
    resources :reports, only: [:index] do
      collection { get :export; get :pdf; post :close; patch :reopen }
    end
    resources :audit_events, only: [:index]
  end
  root 'landing#index'
end
