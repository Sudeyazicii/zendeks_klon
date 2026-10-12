Rails.application.routes.draw do
  root "tickets#index"

  resources :tickets, only: [:index, :show, :new, :create] do
    member do
      patch :update_status
      post :reopen
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

  get "sla_dashboard", to: "tickets#sla_dashboard", as: :sla_dashboard

  get "up" => "rails/health#show", as: :rails_health_check
end
