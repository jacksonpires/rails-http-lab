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
      rel = "environments/#{params[:name]}.bru"
      doc = existing_document(rel) || RailsHttpLab::Bruno::Document.new
      vars_block = doc.block("vars")
      if vars_block
        vars_block.pairs = pairs
      else
        # Bruno writes `vars` first, before e.g. `vars:secret [ ... ]`.
        doc.blocks.unshift(RailsHttpLab::Bruno::Block.new(name: "vars", mode: :kv, pairs: pairs))
      end
      # Only `vars` is editable here; any other block (notably the
      # `vars:secret` list Bruno desktop maintains) is written back untouched.
      storage.write_bru(rel, doc)
      render json: { ok: true }
    end

    private

    def existing_document(rel)
      storage.read_bru(rel)
    rescue RailsHttpLab::NotFoundError
      nil
    end

    def storage
      @storage ||= RailsHttpLab::Storage::Filesystem.new
    end
  end
end
