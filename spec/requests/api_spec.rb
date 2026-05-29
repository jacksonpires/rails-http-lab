require "rails_helper"

RSpec.describe "rails-http-lab API", type: :request do
  let(:engine_root) { "/rails/http-lab" }

  it "GET tree returns the empty collection" do
    get "#{engine_root}/api/tree"
    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body["type"]).to eq("collection")
    expect(body["children"]).to eq([])
  end

  it "PUT /api/requests/:path writes a .bru and tree picks it up" do
    bru_source = <<~BRU
      meta {
        name: Ping
        type: http
        seq: 1
      }

      get {
        url: https://example.com/ping
        body: none
        auth: none
      }
    BRU

    put "#{engine_root}/api/requests/MyAPI/ping.bru", params: { source: bru_source }, as: :json
    expect(response).to have_http_status(:ok)

    body = JSON.parse(response.body)
    expect(body["method"]).to eq("GET")
    expect(body["url"]).to eq("https://example.com/ping")

    get "#{engine_root}/api/tree"
    tree = JSON.parse(response.body)
    api_folder = tree["children"].find { |c| c["name"] == "MyAPI" }
    expect(api_folder).not_to be_nil
    expect(api_folder["children"].first["name"]).to eq("Ping")
  end

  it "POST /api/run interpolates {{vars}} from the chosen environment" do
    WebMock.stub_request(:get, "http://localhost:3000/v0/buyer_fields").to_return(status: 200, body: "ok")

    put "#{engine_root}/api/environments/Local",
        params: { vars: [{ key: "baseUrl", value: "http://localhost:3000" }] }, as: :json
    expect(response).to have_http_status(:ok)

    src = "get {\n  url: {{baseUrl}}/v0/buyer_fields\n  body: none\n  auth: none\n}\n"
    post "#{engine_root}/api/run", params: { source: src, environment: "Local" }, as: :json
    body = JSON.parse(response.body)
    expect(body["error"]).to be_nil
    expect(body["status"]).to eq(200)
  end

  it "POST /api/run executes the saved request" do
    WebMock.stub_request(:get, "https://example.com/ping").to_return(status: 200, body: '{"ok":true}')

    bru = <<~BRU
      get {
        url: https://example.com/ping
        body: none
        auth: none
      }
    BRU
    put "#{engine_root}/api/requests/ping.bru", params: { source: bru }, as: :json

    post "#{engine_root}/api/run", params: { path: "ping.bru" }, as: :json
    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body["status"]).to eq(200)
    expect(body["body"]).to include("ok")
  end

  it "is hidden (404) when env not in enabled_envs" do
    RailsHttpLab.configure { |c| c.enabled_envs = %i[production] }
    get "#{engine_root}/api/tree"
    expect(response).to have_http_status(:not_found)
  end

  describe "folder rename/delete" do
    it "POST /api/folders/rename moves the directory and updates folder.bru meta.name" do
      post "#{engine_root}/api/folders", params: { path: "Acme", name: "Acme" }, as: :json
      expect(response).to have_http_status(:ok)

      post "#{engine_root}/api/folders/rename", params: { path: "Acme", name: "Globex" }, as: :json
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["path"]).to eq("Globex")

      get "#{engine_root}/api/tree"
      tree = JSON.parse(response.body)
      expect(tree["children"].map { |c| c["name"] }).to include("Globex")
      expect(tree["children"].map { |c| c["name"] }).not_to include("Acme")
    end

    it "DELETE /api/folders/:path removes the folder and its contents" do
      post "#{engine_root}/api/folders", params: { path: "Acme", name: "Acme" }, as: :json
      put  "#{engine_root}/api/requests/Acme/ping.bru", params: {
        source: "meta {\n  name: Ping\n  type: http\n  seq: 1\n}\n\nget {\n  url: https://example.com\n  body: none\n  auth: none\n}\n"
      }, as: :json

      delete "#{engine_root}/api/folders/Acme"
      expect(response).to have_http_status(:no_content)

      get "#{engine_root}/api/tree"
      tree = JSON.parse(response.body)
      expect(tree["children"].map { |c| c["name"] }).not_to include("Acme")
    end

    it "rejects rename with a slash in the name" do
      post "#{engine_root}/api/folders", params: { path: "Acme", name: "Acme" }, as: :json
      post "#{engine_root}/api/folders/rename", params: { path: "Acme", name: "foo/bar" }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "request rename" do
    it "POST /api/requests/rename moves the file and updates meta.name" do
      put "#{engine_root}/api/requests/Acme/ping.bru", params: {
        source: "meta {\n  name: Ping\n  type: http\n  seq: 1\n}\n\nget {\n  url: https://example.com\n  body: none\n  auth: none\n}\n"
      }, as: :json

      post "#{engine_root}/api/requests/rename", params: { path: "Acme/ping.bru", name: "pong" }, as: :json
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["path"]).to eq("Acme/pong.bru")

      get "#{engine_root}/api/requests/Acme/pong.bru"
      expect(response).to have_http_status(:ok)
      doc_blocks = JSON.parse(response.body)["blocks"]
      meta = doc_blocks.find { |b| b["name"] == "meta" }
      pair = meta["pairs"].find { |k, _| k == "name" }
      expect(pair[1]).to eq("pong")
    end
  end

  it "top-level collections are returned in alphabetical order" do
    %w[Zebra Apple Mango].each do |name|
      post "#{engine_root}/api/folders", params: { path: name, name: name }, as: :json
    end

    get "#{engine_root}/api/tree"
    names = JSON.parse(response.body)["children"].map { |c| c["name"] }
    expect(names).to eq(%w[Apple Mango Zebra])
  end
end
