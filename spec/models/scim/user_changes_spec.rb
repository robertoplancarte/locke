require "rails_helper"

RSpec.describe Scim::UserChanges do
  describe ".from_resource" do
    it "takes the primary email, the name parts and whether the user is active" do
      resource = {
        "schemas" => [ Scim::USER_SCHEMA ], "userName" => "ada", "externalId" => "kc-1", "active" => false,
        "name" => { "givenName" => "Ada", "familyName" => "Lovelace", "formatted" => "Countess" },
        "emails" => [ { "value" => "ada@home.example" }, { "value" => "ada@example.com", "primary" => true } ],
        "phoneNumbers" => [ { "value" => "555" } ]
      }

      expect(described_class.from_resource(resource)).to eq(email: "ada@example.com", name: "Ada Lovelace", external_id: "kc-1", active: false)
    end

    it "uses the userName as the email when there's no email, and leaves out what wasn't sent" do
      expect(described_class.from_resource("userName" => "ada@example.com")).to eq(email: "ada@example.com")
    end

    it "rejects a body that isn't a resource" do
      expect { described_class.from_resource([]) }.to raise_error(Scim::InvalidRequest) { expect(it.scim_type).to eq("invalidSyntax") }
    end
  end

  describe ".from_patch" do
    subject(:changes) { described_class.from_patch({ "Operations" => operations }, user) }

    let(:user) { build_stubbed(:user, email: "ada@example.com", name: "Ada", external_id: nil) }

    context "with operations by path, as keycloak-scim-outbound sends them" do
      let(:operations) do
        [
          { "op" => "add", "path" => "externalId", "value" => "kc-1" },
          { "op" => "replace", "path" => "name.givenName", "value" => "Augusta" },
          { "op" => "replace", "path" => "name.familyName", "value" => "King" },
          { "op" => "replace", "path" => "emails[primary eq true].value", "value" => "augusta@example.com" },
          { "op" => "replace", "path" => "active", "value" => true }
        ]
      end

      it { is_expected.to eq(email: "augusta@example.com", name: "Augusta King", external_id: "kc-1", active: true) }
    end

    context "with a value of attributes and no path, and capitalised names and strings for booleans, as Entra ID sends them" do
      let(:operations) { [ { "op" => "Replace", "value" => { "active" => "False", "name.formatted" => "Ada King" } } ] }

      it { is_expected.to include(name: "Ada King", active: false, email: "ada@example.com") }
    end

    context "with an operation Locke doesn't know" do
      let(:operations) { [ { "op" => "move", "path" => "active" } ] }

      it { expect { changes }.to raise_error(Scim::InvalidRequest, /Unknown operation/) }
    end
  end
end
