require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#tenant_brand_style_tag" do
    subject(:style_tag) { helper.tenant_brand_style_tag(tenant) }

    context "with a tenant" do
      let(:tenant) { build(:tenant, primary_color: "#FACC15", secondary_color: "#111827") }

      it "sets the brand CSS variables with legible foregrounds" do
        expect(style_tag).to eq(
          "<style>:root { --brand-primary: #FACC15; --brand-primary-foreground: #000000; " \
          "--brand-secondary: #111827; --brand-secondary-foreground: #FFFFFF; }</style>"
        )
      end
    end

    context "without a tenant" do
      let(:tenant) { nil }

      it { is_expected.to be_nil }
    end
  end

  describe "#favicon_link_tags" do
    subject(:tags) { helper.favicon_link_tags(tenant) }

    context "with a tenant that has a logo" do
      let(:tenant) { create(:tenant) }

      before { tenant.logo.attach(fixture_file_upload("wide_logo.png", "image/png")) }

      it "uses the logo resized for each icon" do
        expect(tags).to include(%(<link rel="icon" href="#{helper.url_for(tenant.logo.variant(:favicon))}" type="image/png" sizes="32x32">))
        expect(tags).to include(%(<link rel="apple-touch-icon" href="#{helper.url_for(tenant.logo.variant(:apple_touch_icon))}" sizes="180x180">))
        expect(tags).not_to include("/icon.svg")
      end
    end

    context "with a tenant that has a favicon too" do
      let(:tenant) { create(:tenant) }

      before do
        tenant.logo.attach(fixture_file_upload("wide_logo.png", "image/png"))
        tenant.favicon.attach(fixture_file_upload("square_icon.png", "image/png"))
      end

      it "uses the favicon instead" do
        expect(tags).to include(helper.url_for(tenant.favicon.variant(:favicon)))
        expect(tags).to include(helper.url_for(tenant.favicon.variant(:apple_touch_icon)))
        expect(tags).not_to include(helper.url_for(tenant.logo.variant(:favicon)))
      end
    end

    context "with a tenant without a logo" do
      let(:tenant) { build(:tenant) }

      it "falls back to the default icons" do
        expect(tags).to include(%(<link rel="icon" href="/icon.png" type="image/png">))
        expect(tags).to include(%(<link rel="icon" href="/icon.svg" type="image/svg+xml">))
        expect(tags).to include(%(<link rel="apple-touch-icon" href="/icon.png">))
      end
    end

    context "without a tenant" do
      let(:tenant) { nil }

      it "falls back to the default icons" do
        expect(tags).to include(%(<link rel="icon" href="/icon.png" type="image/png">))
      end
    end
  end
end
