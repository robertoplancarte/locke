Rails.application.routes.draw do
  mount Rails::Hyperdrive::Engine => "/_hyperdrive" if Rails.env.development?
  mount LetterOpenerWeb::Engine => "/letter_opener" if Rails.env.development?
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Tenant workspaces: <subdomain>.<root_domain> or a verified custom domain
  constraints(->(request) { !Tenant.root_host?(request.host) }) do
    namespace :settings do
      resource :branding, only: %i[edit update]
      resource :authentication, only: %i[edit update]
      resources :domains, only: %i[index create destroy] do
        resource :check, only: :create, module: :domains
      end
    end

    # Accounts belong to one tenant, so authentication only exists on tenant hosts
    get  "sign_in", to: "sessions#new"
    post "sign_in", to: "sessions#create"
    get  "sign_up", to: "registrations#new"
    post "sign_up", to: "registrations#create"
    resources :sessions, only: [:index, :show, :destroy]
    resource  :password, only: [:edit, :update]
    namespace :identity do
      resource :email,              only: [:edit, :update]
      resource :email_verification, only: [:show, :create]
      resource :password_reset,     only: [:new, :edit, :create, :update]
    end
    namespace :authentications do
      resources :events, only: :index
    end
    namespace :two_factor_authentication do
      namespace :challenge do
        resource :security_keys,  only: [:new, :create]
        resource :totp,           only: [:new, :create]
        resource :recovery_codes, only: [:new, :create]
      end
      namespace :profile do
        resources :security_keys
        resource  :totp,           only: [:new, :create, :update]
        resources :recovery_codes, only: [:index, :create]
      end
    end
    get  "/auth/failure",            to: "sessions/omniauth#failure"
    get  "/auth/:provider/callback", to: "sessions/omniauth#create"
    post "/auth/:provider/callback", to: "sessions/omniauth#create"
    post "users/:user_id/masquerade", to: "masquerades#create", as: :user_masquerade
    resource :invitation, only: [:new, :create]
    namespace :sessions do
      resource :passwordless, only: [:edit, :create]
      resource :sudo, only: [:new, :create]
    end

    root "home#index"
  end

  # A directory of tenant workspaces on the bare root domain, for finding your
  # way around locally. Never in production, where it would list every customer.
  if Rails.env.local?
    get "/", to: "development/tenants#index", as: :tenant_directory
  end
end
