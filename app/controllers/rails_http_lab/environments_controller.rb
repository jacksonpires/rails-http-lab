module RailsHttpLab
  class EnvironmentsController < ApplicationController
    skip_forgery_protection only: [:update]

    def index
      render json: { environments: RailsHttpLab::Storage::Tree.new.build[:environments] }
    end

    def show
      doc = storage.read_bru("environments/#{params[:name]}.bru")
      vars = doc.block("vars")&.pairs || []
      render json: { name: params[:name], vars: vars }
    end

    def update
      pairs = Array(params[:vars]).map { |v|
        v = v.to_unsafe_h if v.respond_to?(:to_unsafe_h)
        [v["key"].to_s, v["value"].to_s]
      }
      doc = RailsHttpLab::Bruno::Document.new(blocks: [
        RailsHttpLab::Bruno::Block.new(name: "vars", mode: :kv, pairs: pairs)
      ])
      storage.write_bru("environments/#{params[:name]}.bru", doc)
      render json: { ok: true }
    end

    private

    def storage
      @storage ||= RailsHttpLab::Storage::Filesystem.new
    end
  end
end
