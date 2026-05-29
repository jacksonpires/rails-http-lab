require "spec_helper"

RSpec.describe RailsHttpLab::Bruno::Serializer do
  it "emits kv block with 2-space indent and trailing newline" do
    doc = RailsHttpLab::Bruno::Document.new(blocks: [
      RailsHttpLab::Bruno::Block.new(name: "meta", mode: :kv, pairs: [["name", "X"], ["seq", "1"]])
    ])
    expect(described_class.dump(doc)).to eq("meta {\n  name: X\n  seq: 1\n}\n")
  end

  it "emits raw block verbatim" do
    raw_body = "  {\n    \"a\": 1\n  }"
    doc = RailsHttpLab::Bruno::Document.new(blocks: [
      RailsHttpLab::Bruno::Block.new(name: "body:json", mode: :raw, raw: raw_body)
    ])
    expect(described_class.dump(doc)).to eq("body:json {\n  {\n    \"a\": 1\n  }\n}\n")
  end

  it "joins multiple blocks with a single blank line" do
    doc = RailsHttpLab::Bruno::Document.new(blocks: [
      RailsHttpLab::Bruno::Block.new(name: "meta", mode: :kv, pairs: [["name", "X"]]),
      RailsHttpLab::Bruno::Block.new(name: "get",  mode: :kv, pairs: [["url", "https://x"]])
    ])
    expect(described_class.dump(doc)).to eq("meta {\n  name: X\n}\n\nget {\n  url: https://x\n}\n")
  end
end
