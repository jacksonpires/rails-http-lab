require "spec_helper"
require "webmock/rspec"

RSpec.describe RailsHttpLab::Execution::Runner do
  before { WebMock.disable_net_connect! }
  after  { WebMock.reset! }

  def parse(src)
    RailsHttpLab::Bruno.parse(src)
  end

  it "executes a GET with query params" do
    stub = WebMock.stub_request(:get, "https://example.com/users")
      .with(query: { "id" => "42" })
      .to_return(status: 200, body: '{"ok":true}', headers: { "Content-Type" => "application/json" })

    doc = parse(<<~BRU)
      get {
        url: https://example.com/users
        body: none
        auth: none
      }

      params:query {
        id: 42
      }
    BRU

    resp = described_class.new(doc).run
    expect(resp.status).to eq(200)
    expect(resp.body).to include("ok")
    expect(stub).to have_been_requested
  end

  it "executes POST with json body and bearer auth" do
    stub = WebMock.stub_request(:post, "https://example.com/items")
      .with(
        body:    { name: "x" }.to_json,
        headers: { "Authorization" => "Bearer abc", "Content-Type" => "application/json" }
      ).to_return(status: 201, body: "{}")

    doc = parse(<<~BRU)
      post {
        url: https://example.com/items
        body: json
        auth: bearer
      }

      auth:bearer {
        token: abc
      }

      body:json {
        {"name":"x"}
      }
    BRU

    resp = described_class.new(doc).run
    expect(resp.status).to eq(201)
    expect(stub).to have_been_requested
  end

  it "resolves {{vars}} from the resolver" do
    stub = WebMock.stub_request(:get, "https://example.com/v/42").to_return(status: 200, body: "")

    doc = parse(<<~BRU)
      get {
        url: {{baseUrl}}/v/{{id}}
        body: none
        auth: none
      }
    BRU

    resolver = RailsHttpLab::Execution::VariableResolver.new("baseUrl" => "https://example.com", "id" => "42")
    resp = described_class.new(doc, resolver: resolver).run
    expect(resp.status).to eq(200)
    expect(stub).to have_been_requested
  end

  it "captures errors instead of raising" do
    doc = parse(<<~BRU)
      get {
        url: not a url
        body: none
        auth: none
      }
    BRU

    resp = described_class.new(doc).run
    expect(resp.error).not_to be_nil
  end

  it "returns the resolved request (method, url, headers, body) on success" do
    WebMock.stub_request(:post, "https://example.com/items").to_return(status: 201, body: "{}")

    doc = parse(<<~BRU)
      post {
        url: {{baseUrl}}/items
        body: json
        auth: bearer
      }

      auth:bearer {
        token: abc
      }

      body:json {
        {"name":"x"}
      }
    BRU

    resolver = RailsHttpLab::Execution::VariableResolver.new("baseUrl" => "https://example.com")
    resp = described_class.new(doc, resolver: resolver).run

    expect(resp.request).to be_a(Hash)
    expect(resp.request[:method]).to eq("POST")
    expect(resp.request[:url]).to    eq("https://example.com/items")
    expect(resp.request[:headers]["authorization"]).to eq("Bearer abc")
    expect(resp.request[:headers]["content-type"]).to  eq("application/json")
    expect(resp.request[:body]).to eq('{"name":"x"}')
  end
end
