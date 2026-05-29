require "spec_helper"

RSpec.describe RailsHttpLab::Bruno::Parser do
  describe ".parse" do
    it "parses meta + verb + headers" do
      src = <<~BRU
        meta {
          name: Login
          type: http
          seq: 1
        }

        post {
          url: https://api.example.com/auth
          body: json
          auth: none
        }

        headers {
          Content-Type: application/json
        }
      BRU

      doc = described_class.parse(src)
      expect(doc.blocks.map(&:name)).to eq(%w[meta post headers])
      expect(doc.block("meta")["name"]).to eq("Login")
      expect(doc.block("meta")["seq"]).to eq("1")
      expect(doc.http_method).to eq("POST")
      expect(doc.url).to eq("https://api.example.com/auth")
      expect(doc.block("headers")["Content-Type"]).to eq("application/json")
    end

    it "parses raw body:json preserving content" do
      src = <<~BRU
        post {
          url: https://api.example.com
          body: json
          auth: none
        }

        body:json {
          {
            "a": 1,
            "nested": { "b": 2 }
          }
        }
      BRU

      doc = described_class.parse(src)
      raw = doc.block("body:json").raw
      expect(raw).to include('"a": 1')
      expect(raw).to include('"nested": { "b": 2 }')
    end

    it "parses params:query and auth:bearer variants" do
      src = <<~BRU
        get {
          url: https://x/y
          body: json
          auth: bearer
        }

        params:query {
          a: 1
          b: 2
        }

        auth:bearer {
          token: abc.def.ghi
        }
      BRU

      doc = described_class.parse(src)
      expect(doc.block("params:query").pairs).to eq([["a", "1"], ["b", "2"]])
      expect(doc.block("auth:bearer")["token"]).to eq("abc.def.ghi")
    end

    it "rejects malformed input" do
      expect { described_class.parse("garbage line\n") }.to raise_error(RailsHttpLab::ParseError)
    end

    it "rejects unterminated blocks" do
      expect { described_class.parse("meta {\n  name: x\n") }.to raise_error(RailsHttpLab::ParseError)
    end
  end
end
