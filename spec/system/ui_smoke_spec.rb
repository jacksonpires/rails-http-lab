require "rails_helper"

RSpec.describe "UI smoke", type: :request do
  it "renders the SPA shell at the mount root" do
    get "/rails/http-lab/"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Rails HTTP Lab")
    expect(response.body).to include("rhl-app")
    expect(response.body).to include('id="rhl-tree"')
  end
end
