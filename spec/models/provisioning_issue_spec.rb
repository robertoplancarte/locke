require "rails_helper"

RSpec.describe ProvisioningIssue do
  include ActiveSupport::Testing::TimeHelpers

  let_it_be(:tenant) { create(:tenant) }
  let_it_be(:identity_provider) { create(:identity_provider, tenant:) }

  around { |example| ActsAsTenant.with_tenant(tenant) { example.run } }

  describe ".report" do
    def report(message = "Couldn't update ada@example.com") =
      described_class.report(identity_provider:, source: :scim, message:, details: { email: "ada@example.com" })

    it "counts the same unresolved problem again instead of opening another issue" do
      first = report
      travel 1.hour do
        expect(report).to eq(first)
        expect(first.reload).to have_attributes(occurrences: 2, last_occurred_at: be_within(1.second).of(Time.current))
      end
    end

    it "opens a new issue once the old one is resolved, or for a different problem" do
      report.resolve

      expect { report; report("Something else") }.to change(described_class.unresolved, :count).by(2)
    end
  end
end
