module RailsHttpLab
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception, prepend: true
    layout "rails_http_lab"

    before_action :guard_environment!

    rescue_from RailsHttpLab::NotFoundError,        with: :render_not_found
    rescue_from RailsHttpLab::OutsideStorageError,  with: :render_forbidden
    rescue_from RailsHttpLab::ParseError,           with: :render_unprocessable
    rescue_from RailsHttpLab::Error,                with: :render_unprocessable

    private

    def guard_environment!
      cfg = RailsHttpLab.config
      env_sym = Rails.env.to_sym
      unless cfg.enabled_envs.include?(env_sym)
        head :not_found and return
      end
      if cfg.authenticator && !cfg.authenticator.call(request)
        head :forbidden and return
      end
    end

    def render_not_found(error)
      respond_to do |format|
        format.json { render json: { error: error.message }, status: :not_found }
        format.any  { head :not_found }
      end
    end

    def render_forbidden(error)
      respond_to do |format|
        format.json { render json: { error: error.message }, status: :forbidden }
        format.any  { head :forbidden }
      end
    end

    def render_unprocessable(error)
      respond_to do |format|
        format.json { render json: { error: error.message }, status: :unprocessable_entity }
        format.any  { head :unprocessable_entity }
      end
    end
  end
end
