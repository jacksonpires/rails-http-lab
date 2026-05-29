module RailsHttpLab
  class FoldersController < ApplicationController
    skip_forgery_protection only: [:create, :rename, :destroy]

    def create
      path = params.require(:path).to_s
      RailsHttpLab::Storage::Filesystem.new.create_folder(path, display_name: params[:name])
      render json: { ok: true, path: path }
    end

    def rename
      from     = params.require(:path).to_s
      new_name = params.require(:name).to_s.strip
      raise RailsHttpLab::Error, "name cannot be empty" if new_name.empty?
      raise RailsHttpLab::Error, "name cannot contain '/' or '\\'" if new_name.match?(%r{[/\\]})

      parent = File.dirname(from)
      parent = "" if parent == "."
      to = parent.empty? ? new_name : "#{parent}/#{new_name}"

      fs = RailsHttpLab::Storage::Filesystem.new
      fs.rename(from, to)
      update_folder_meta_name(fs, to, new_name)

      render json: { ok: true, path: to }
    end

    def destroy
      path = params.require(:path).to_s
      RailsHttpLab::Storage::Filesystem.new.delete(path)
      head :no_content
    end

    private

    def update_folder_meta_name(fs, folder_path, new_name)
      meta_path = "#{folder_path}/folder.bru"
      doc  = fs.read_bru(meta_path)
      meta = doc.block("meta")
      return unless meta&.kv?
      meta["name"] = new_name
      fs.write_bru(meta_path, doc)
    rescue RailsHttpLab::NotFoundError
      # folder had no folder.bru — nothing to update
    end
  end
end
