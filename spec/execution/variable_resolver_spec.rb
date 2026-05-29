require "spec_helper"

RSpec.describe RailsHttpLab::Execution::VariableResolver do
  it "substitutes {{vars}}" do
    r = described_class.new("baseUrl" => "https://api.local", "id" => "42")
    expect(r.resolve("{{baseUrl}}/users/{{id}}")).to eq("https://api.local/users/42")
  end

  it "leaves unknown vars untouched" do
    r = described_class.new("known" => "ok")
    expect(r.resolve("{{known}} and {{unknown}}")).to eq("ok and {{unknown}}")
  end

  it "ignores non-string input" do
    expect(described_class.new.resolve(nil)).to be_nil
    expect(described_class.new.resolve(42)).to eq(42)
  end

  it "loads from an environment document" do
    src = "vars {\n  baseUrl: http://localhost\n}\n"
    doc = RailsHttpLab::Bruno.parse(src)
    r = described_class.from_environment_document(doc)
    expect(r.resolve("{{baseUrl}}/x")).to eq("http://localhost/x")
  end
end
