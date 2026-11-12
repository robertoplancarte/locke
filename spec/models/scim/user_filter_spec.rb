require "rails_helper"

RSpec.describe Scim::UserFilter do
  let_it_be(:tenant) { create(:tenant) }
  let_it_be(:ada) { create(:user, tenant:, email: "ada@example.com", external_id: "kc-1") }
  let_it_be(:grace) { create(:user, tenant:, email: "grace@example.com") }

  around { |example| ActsAsTenant.with_tenant(tenant) { example.run } }

  def users(filter) = described_class.new(filter).apply(User.all).to_a

  it "finds users by userName, email or externalId, ignoring the attribute's case" do
    expect(users('userName eq "ADA@example.com"')).to eq([ ada ])
    expect(users('emails.value eq "grace@example.com"')).to eq([ grace ])
    expect(users('externalid EQ "kc-1"')).to eq([ ada ])
  end

  it "returns everyone without a filter" do
    expect(users(nil)).to contain_exactly(ada, grace)
  end

  it "rejects filters it doesn't support" do
    expect { users('userName sw "ada"') }.to raise_error(Scim::InvalidRequest) { expect(it.scim_type).to eq("invalidFilter") }
  end
end
