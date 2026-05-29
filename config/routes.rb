RailsHttpLab::Engine.routes.draw do
  root to: "ui#index"

  scope "api", defaults: { format: :json } do
    get    "tree",                       to: "collections#tree"
    post   "collections",                to: "collections#create"

    post   "folders",                    to: "folders#create"
    post   "folders/rename",             to: "folders#rename"
    delete "folders/*path",              to: "folders#destroy", constraints: { path: /.*/ }

    post   "requests/rename",            to: "requests#rename"
    get    "requests/*path",             to: "requests#show",    constraints: { path: /.*/ }
    put    "requests/*path",             to: "requests#update",  constraints: { path: /.*/ }
    delete "requests/*path",             to: "requests#destroy", constraints: { path: /.*/ }
    post   "requests",                   to: "requests#create"

    get    "environments",               to: "environments#index"
    get    "environments/:name",         to: "environments#show"
    put    "environments/:name",         to: "environments#update"

    post   "run",                        to: "runs#create"
  end
end
