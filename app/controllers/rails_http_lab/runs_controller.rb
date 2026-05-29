module RailsHttpLab
  class RunsController < ApplicationController
    skip_forgery_protection only: [:create]

    def create
      doc = build_document
      resolver = build_resolver
      response = RailsHttpLab::Execution::Runner.new(doc, resolver: resolver).run
      render json: response.to_h
    end

    private

    def build_document
      if params[:path].present?
        RailsHttpLab::Storage::Filesystem.new.read_bru(params[:path])
      elsif params[:source].present?
        RailsHttpLab::Bruno.parse(params[:source].to_s)
      else
        raise RailsHttpLab::Error, "missing :path or :source"
      end
    end

    def build_resolver
      env_name = params[:environment].to_s
      return RailsHttpLab::Execution::VariableResolver.new if env_name.empty?

      env_doc = RailsHttpLab::Storage::Filesystem.new.read_bru("environments/#{env_name}.bru")
      RailsHttpLab::Execution::VariableResolver.from_environment_document(env_doc)
    rescue RailsHttpLab::NotFoundError
      RailsHttpLab::Execution::VariableResolver.new
    end
  end
end
