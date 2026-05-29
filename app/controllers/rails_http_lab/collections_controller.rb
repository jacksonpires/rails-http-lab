module RailsHttpLab
  class CollectionsController < ApplicationController
    skip_forgery_protection only: [:create]

    def tree
      RailsHttpLab::Storage::Filesystem.new.ensure_root!
      render json: RailsHttpLab::Storage::Tree.new.build
    end

    def create
      name = params.require(:name).to_s
      fs = RailsHttpLab::Storage::Filesystem.new
      fs.ensure_root!
      manifest = fs.read_bruno_json || {}
      manifest["name"] = name if manifest["name"].to_s.empty?
      File.write(File.join(fs.root.to_s, "bruno.json"), JSON.pretty_generate(manifest) + "\n")
      render json: { ok: true, name: manifest["name"] }
    end
  end
end
