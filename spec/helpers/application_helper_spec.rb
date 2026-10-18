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
end
