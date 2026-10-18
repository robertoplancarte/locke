require "rails_helper"

RSpec.describe BrandColor do
  describe "#foreground" do
    {
      "#FFFFFF" => "#000000",
      "#FACC15" => "#000000",
      "#000000" => "#FFFFFF",
      "#4F46E5" => "#FFFFFF",
      "#DC2626" => "#FFFFFF"
    }.each do |hex, foreground|
      it "is #{foreground} on #{hex}" do
        expect(described_class.new(hex).foreground).to eq(foreground)
      end
    end
  end

  describe "#luminance" do
    it "spans 0 for black to 1 for white" do
      expect(described_class.new("#000000").luminance).to eq(0)
      expect(described_class.new("#FFFFFF").luminance).to be_within(0.0001).of(1)
    end
  end
end
