Rails.application.routes.draw do
  mount Rails::Hyperdrive::Engine => "/_hyperdrive" if Rails.env.development?
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
      resources :domains, only: %i[index create destroy] do
        resource :check, only: :create, module: :domains
      end
    end

    root to: redirect("/settings/branding/edit", status: 302), as: :tenant_root
  end

  # A directory of tenant workspaces on the bare root domain, for finding your
  # way around locally. Never in production, where it would list every customer.
  if Rails.env.local?
    root "development/tenants#index"
  end
end
