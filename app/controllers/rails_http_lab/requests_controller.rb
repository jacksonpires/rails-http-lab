module RailsHttpLab
  class RequestsController < ApplicationController
    skip_forgery_protection only: [:create, :update, :destroy, :rename]

    def show
      doc = storage.read_bru(path_param)
      render json: serialize(doc, path_param)
    end

    def update
      doc = doc_from_params
      storage.write_bru(path_param, doc)
      render json: serialize(doc, path_param)
    end

    def create
      rel = params.require(:path).to_s
      doc = doc_from_params
      storage.write_bru(rel, doc)
      render json: serialize(doc, rel)
    end

    def destroy
      storage.delete(path_param)
      head :no_content
    end

    def rename
      from     = params.require(:path).to_s
      new_name = params.require(:name).to_s.strip
      raise RailsHttpLab::Error, "name cannot be empty" if new_name.empty?
      raise RailsHttpLab::Error, "name cannot contain '/' or '\\'" if new_name.match?(%r{[/\\]})

      base   = new_name.sub(/\.bru\z/i, "")
      parent = File.dirname(from)
      parent = "" if parent == "."
      to = parent.empty? ? "#{base}.bru" : "#{parent}/#{base}.bru"

      storage.rename(from, to)
      doc  = storage.read_bru(to)
      meta = doc.block("meta")
      if meta&.kv?
        meta["name"] = base
        storage.write_bru(to, doc)
      end

      render json: serialize(doc, to)
    end

    private

    def storage
      @storage ||= RailsHttpLab::Storage::Filesystem.new
    end

    def path_param
      params[:path].to_s
    end

    def doc_from_params
      raw = params[:source].to_s
      return RailsHttpLab::Bruno.parse(raw) unless raw.empty?

      RailsHttpLab::Bruno.parse(blocks_to_source(params[:blocks]))
    end

    # Accepts an array of { name, mode, pairs|raw } and rebuilds a Document.
    def blocks_to_source(blocks)
      blocks = blocks.respond_to?(:to_unsafe_h) ? blocks.to_unsafe_h.values : blocks
      docs = []
      Array(blocks).each do |b|
        b = b.to_unsafe_h if b.respond_to?(:to_unsafe_h)
        mode = b["mode"]&.to_sym || :kv
        if mode == :raw
          docs << "#{b['name']} {\n#{b['raw']}\n}\n"
        else
          lines = Array(b["pairs"]).map { |k, v| "  #{k}: #{v}" }.join("\n")
          docs << "#{b['name']} {\n#{lines}#{lines.empty? ? '' : "\n"}}\n"
        end
      end
      docs.join("\n")
    end

    def serialize(doc, rel)
      {
        path:   rel,
        method: doc.http_method,
        url:    doc.url,
        blocks: doc.blocks.map { |b|
          if b.kv?
            { name: b.name, mode: "kv", pairs: b.pairs }
          else
            { name: b.name, mode: "raw", raw: b.raw }
          end
        }
      }
    end
  end
end
