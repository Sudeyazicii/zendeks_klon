Rails.application.routes.draw do
  root "tickets#index"

  resources :tickets, only: [:index, :show, :new, :create] do
    member do
      patch :update_status
      post :reopen
      patch :close
      post :merge
      patch :assign
    end
    resources :ticket_comments, only: [:create]
  end

  resources :community_questions, only: [:index, :show, :new, :create] do
    member do
      post :convert_to_ticket
    end
    resources :community_answers, only: [:create]
    collection do
      post :trigger_auto_convert
    end
  end

  resources :automations, only: [:index, :new, :create] do
    member do
      get :preview
      post :execute
      patch :toggle
    end
    collection do
      get :audit_logs
    end
  end

  resources :notifications, only: [:index] do
    member do
      patch :mark_as_read
    end
    collection do
      post :mark_all_as_read
    end
  end

  resources :reports, only: [:index] do
    collection do
      get :export_csv
    end
  end

  get "sla_dashboard", to: "tickets#sla_dashboard", as: :sla_dashboard
  post "switch_role", to: "application#switch_role", as: :switch_role

  get "up" => "rails/health#show", as: :rails_health_check
end
