# Registering apps and managing ID token signing keys. Secrets are only stored
# as digests, so each is printed once, here.
namespace :oauth do
  namespace :app do
    desc "Register an app on every tenant: oauth:app:global[name,https://app.example.com/callback]"
    task :global, %i[name redirect_uri] => :environment do |_task, args|
      ActsAsTenant.without_tenant { print_app OauthApplication.create!(name: args.fetch(:name), redirect_uri: args.fetch(:redirect_uri)) }
    end

    desc "Register an app on one tenant: oauth:app:tenant[acme,name,https://app.example.com/callback]"
    task :tenant, %i[subdomain name redirect_uri] => :environment do |_task, args|
      tenant = Tenant.find_by!(subdomain: args.fetch(:subdomain))
      ActsAsTenant.with_tenant(tenant) { print_app OauthApplication.create!(name: args.fetch(:name), redirect_uri: args.fetch(:redirect_uri)) }
    end

    def print_app(app)
      puts "#{app.name} (#{app.global? ? "every tenant" : app.tenant.subdomain})"
      puts "  client_id:     #{app.uid}"
      puts "  client_secret: #{app.plaintext_secret}"
      puts "  Shown once: only a digest is stored."
    end
  end

  namespace :signing_key do
    desc "Create a new ID token signing key; it signs from now on, and older keys stay published"
    task rotate: :environment do
      key = SigningKey.generate!
      puts "Signing key #{key.id} is now active. Retire older keys once their ID tokens have expired:"
      SigningKey.active.where.not(id: key.id).each { puts "  bin/rails oauth:signing_key:retire[#{_1.id}]" }
    end

    desc "Stop publishing a signing key: oauth:signing_key:retire[id]"
    task :retire, %i[id] => :environment do |_task, args|
      key = SigningKey.active.find(args.fetch(:id))
      abort "Key #{key.id} is the only active key; rotate first." if SigningKey.active.one?
      key.retire!
      puts "Signing key #{key.id} retired."
    end
  end
end
