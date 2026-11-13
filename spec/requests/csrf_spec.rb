require "rails_helper"

# The runner sends HTTP requests from the Rails server and the API writes files
# into the host repo, so a cross-site form POST must never reach a mutating
# endpoint. These specs pin that every non-GET route verifies the CSRF token.
RSpec.describe "CSRF protection", type: :request do
  let(:engine_root) { "/rails/http-lab" }
  let(:storage_root) { RailsHttpLab.config.resolved_storage_path.to_s }

  # Derived from the engine's route table so a newly added mutating route is
  # covered automatically.
  mutating_routes = RailsHttpLab::Engine.routes.routes.filter_map do |route|
    verb = route.verb.to_s
    next if verb.empty? || verb.match?(/\A(GET|HEAD)\z/)

    path = route.path.spec.to_s.sub("(.:format)", "")
                .sub("*path", "Acme/ping.bru")
                .sub(":name", "Local")
    [verb, path]
  end

  it "covers every mutating route of the engine" do
    expect(mutating_routes.map(&:first).uniq).to contain_exactly("POST", "PUT", "DELETE")
    expect(mutating_routes.size).to be >= 10 # sanity: enumeration found the routes
  end

  it "the SPA shell exposes a csrf-token meta tag for the frontend" do
    get "#{engine_root}/"
    expect(response.body).to match(/<meta name="csrf-token" content="[^"]+"/)
  end

  mutating_routes.each do |verb, path|
    it "#{verb} #{path} is rejected with 422 without a CSRF token" do
      process verb.downcase.to_sym, "#{engine_root}#{path}", params: { path: "Acme/x.bru", name: "x" }, as: :json
      expect(response).to have_http_status(422)
      expect(JSON.parse(response.body)["error"]).to match(/CSRF/)
    end
  end

  it "rejects a cross-site form POST to /api/run without sending anything" do
    stub = WebMock.stub_request(:any, /internal\.example/)
    src = "get {\n  url: http://internal.example/admin\n  body: none\n  auth: none\n}\n"

    post "#{engine_root}/api/run",
         params: { source: src },
         headers: { "Origin" => "https://evil.example", "Content-Type" => "application/x-www-form-urlencoded" }

    expect(response).to have_http_status(422)
    expect(stub).not_to have_been_requested
  end

  it "rejects a forged POST /api/requests without writing the file" do
    post "#{engine_root}/api/requests",
         params: { path: "pwned.bru", source: "get {\n  url: http://x\n}\n" }
    expect(response).to have_http_status(422)
    expect(File).not_to exist(File.join(storage_root, "pwned.bru"))
  end

  it "rejects a wrong CSRF token" do
    csrf_headers # start a session with a real token
    post "#{engine_root}/api/folders", params: { path: "Acme", name: "Acme" },
                                       headers: { "X-CSRF-Token" => "not-the-token" }, as: :json
    expect(response).to have_http_status(422)
    expect(Dir).not_to exist(File.join(storage_root, "Acme"))
  end

  it "accepts a body-less DELETE that carries the token in the header" do
    post "#{engine_root}/api/folders", params: { path: "Acme", name: "Acme" }, headers: csrf_headers, as: :json
    expect(response).to have_http_status(:ok)

    delete "#{engine_root}/api/folders/Acme", headers: csrf_headers
    expect(response).to have_http_status(:no_content)
    expect(Dir).not_to exist(File.join(storage_root, "Acme"))
  end

  it "keeps a disabled engine a plain 404 for a POST without a token" do
    RailsHttpLab.configure { |c| c.enabled_envs = %i[production] }
    post "#{engine_root}/api/run", params: { source: "get {\n  url: http://x\n}\n" }, as: :json
    expect(response).to have_http_status(:not_found)
  end
end
