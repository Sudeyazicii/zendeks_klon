Rails.application.routes.draw do
  root "tickets#index"

  # Agent Marketplace (Pazaryeri & Bayram Paketi)
  get    "marketplace", to: "marketplace#index", as: :marketplace
  post   "marketplace/hire_bayram_pack", to: "marketplace#hire_bayram_pack", as: :hire_bayram_pack_marketplace
  post   "marketplace/rent_agent/:id", to: "marketplace#rent_agent", as: :rent_agent_marketplace
  delete "marketplace/cancel_rental/:id", to: "marketplace#cancel_rental", as: :cancel_rental_marketplace
  post   "marketplace/simulate_surge", to: "marketplace#simulate_surge", as: :simulate_surge_marketplace
  get    "marketplace/review_queue", to: "marketplace#review_queue", as: :review_queue_marketplace
  post   "marketplace/approve_log/:id", to: "marketplace#approve_log", as: :approve_log_marketplace
  post   "marketplace/reject_log/:id", to: "marketplace#reject_log", as: :reject_log_marketplace

  resources :tickets do
    member do
      patch :update_status
      post :reopen
      patch :close
      post :merge
      patch :assign
      post :ai_summarize
      post :ai_draft_reply
    end
    resources :ticket_comments, only: [:create]
  end

  resources :canned_responses

  resources :community_questions, only: [:index, :show, :new, :create] do
    member do
      post :convert_to_ticket
    end
    resources :community_answers, only: [:create] do
      member do
        post :mark_solution
        post :upvote
      end
    end
    collection do
      post :trigger_auto_convert
    end
  end

  resources :automations do
    member do
      get :preview
      post :execute
      patch :toggle
    end
    collection do
      get :audit_logs
    end
  end

  resources :articles

  resources :notifications, only: [:index] do
    member do
      patch :mark_as_read
    end
    collection do
      post :mark_all_as_read
    end
  end

  resources :sent_emails, only: [:index, :show]

  resources :reports, only: [:index] do
    collection do
      get :export_csv
    end
  end

  # Omnichannel Webhooks (WhatsApp, Live Chat, External API)
  post "webhooks/incoming_message", to: "webhooks#incoming_message"

  get  "sla_dashboard", to: "tickets#sla_dashboard", as: :sla_dashboard
  match "switch_role", to: "application#switch_role", via: [:get, :post], as: :switch_role

  get   "profile",  to: "users#profile",            as: :profile
  patch "profile",  to: "users#update_preferences", as: :update_preferences

  # Admin: Kullanıcı Yönetim Paneli
  get   "admin/users",          to: "users#index",       as: :admin_users
  patch "admin/users/:id/role", to: "users#update_role", as: :admin_update_user_role

  # Gerçek Kimlik Doğrulama (Login / Logout)
  get  "login",  to: "users#login",        as: :login
  post "login",  to: "users#authenticate"
  match "logout", to: "users#logout", via: [:get, :delete, :post], as: :logout

  get "up" => "rails/health#show", as: :rails_health_check
end
