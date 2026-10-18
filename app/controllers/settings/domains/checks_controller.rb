module Settings
  module Domains
    class ChecksController < ApplicationController
      def create
        domain = current_tenant.domains.find(params[:domain_id])
        domain.sync_later

        redirect_to settings_domains_path, notice: "Checking #{domain.hostname} with Cloudflare…"
      end
    end
  end
end
