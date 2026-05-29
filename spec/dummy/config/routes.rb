Rails.application.routes.draw do
  mount RailsHttpLab::Engine => RailsHttpLab.config.mount_path
end
