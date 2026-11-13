module RailsHttpLab
  class ApplicationController < ActionController::Base
    layout "rails_http_lab"

    # Order matters: the environment gate runs first so a disabled engine is
    # still a plain 404 (even for a POST without a token) instead of revealing
    # itself with a CSRF 422. Every mutating endpoint is then CSRF-verified —
    # the runner makes requests from the server, so a cross-site form POST must
    # never reach it. Do not add skip_forgery_protection to subclasses.
    before_action :guard_environment!
    protect_from_forgery with: :exception

    rescue_from ActionController::InvalidAuthenticityToken, with: :render_invalid_csrf
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

    def render_invalid_csrf(_error)
      respond_to do |format|
        format.json { render json: { error: "invalid or missing CSRF token — reload the page" }, status: 422 }
        format.any  { head 422 }
      end
    end

    def render_unprocessable(error)
      respond_to do |format|
        format.json { render json: { error: error.message }, status: 422 }
        format.any  { head 422 }
      end
    end
  end
end
