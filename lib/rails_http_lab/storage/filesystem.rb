require "json"
require "fileutils"
require "pathname"

module RailsHttpLab
  module Storage
    # Filesystem-backed CRUD for Bruno collections under config.storage_path.
    #
    # All paths are relative to the storage root. The class refuses to operate
    # on absolute paths, paths containing "..", or paths that escape the root
    # after resolution.
    class Filesystem
      def initialize(root: RailsHttpLab.config.resolved_storage_path)
        @root = Pathname.new(root.to_s)
      end

      attr_reader :root

      def root_exists?
        @root.directory?
      end

      def ensure_root!
        FileUtils.mkdir_p(@root) unless @root.directory?
        unless (@root + "bruno.json").file?
          File.write(@root + "bruno.json", default_bruno_json)
        end
      end

      def read_bru(relative_path)
        abs = safe_path(relative_path)
        raise NotFoundError, "no such file: #{relative_path}" unless abs.file?
        Bruno.parse(abs.read)
      end

      def write_bru(relative_path, document)
        abs = safe_path(relative_path)
        FileUtils.mkdir_p(abs.dirname)
        File.write(abs, Bruno.dump(document))
        document
      end

      def delete(relative_path)
        abs = safe_path(relative_path)
        return false unless abs.exist?
        if abs.directory?
          FileUtils.rm_rf(abs)
        else
          abs.delete
        end
        true
      end

      # Moves a file or directory from one relative path to another. Both paths
      # are validated through safe_path. Refuses if destination already exists.
      def rename(from, to)
        abs_from = safe_path(from)
        raise NotFoundError, "no such path: #{from}" unless abs_from.exist?
        abs_to = safe_path(to)
        raise Error, "destination exists: #{to}" if abs_to.exist?
        FileUtils.mkdir_p(abs_to.dirname)
        FileUtils.mv(abs_from.to_s, abs_to.to_s)
        abs_to
      end

      def create_folder(relative_path, display_name: nil)
        abs = safe_path(relative_path)
        FileUtils.mkdir_p(abs)
        folder_meta = abs + "folder.bru"
        unless folder_meta.file?
          name = display_name || abs.basename.to_s
          doc = Bruno::Document.new(blocks: [
            Bruno::Block.new(name: "meta", mode: :kv, pairs: [
              ["name", name],
              ["seq",  next_seq(abs.dirname).to_s]
            ])
          ])
          File.write(folder_meta, Bruno.dump(doc))
        end
        relative_path
      end

      def read_bruno_json
        path = @root + "bruno.json"
        return nil unless path.file?
        JSON.parse(path.read)
      end

      private

      def safe_path(relative_path)
        rel = relative_path.to_s
        raise OutsideStorageError, "empty path" if rel.empty?
        raise OutsideStorageError, "absolute path forbidden: #{rel}" if rel.start_with?("/")
        raise OutsideStorageError, "traversal forbidden: #{rel}" if rel.split("/").include?("..")
        abs = (@root + rel).cleanpath
        unless abs.to_s == @root.to_s || abs.to_s.start_with?(@root.to_s + "/")
          raise OutsideStorageError, "outside storage root: #{rel}"
        end
        abs
      end

      def default_bruno_json
        JSON.pretty_generate(
          "version" => "1",
          "name"    => "My APIs",
          "type"    => "collection",
          "ignore"  => ["node_modules", ".git"]
        ) + "\n"
      end

      def next_seq(dir)
        existing = Dir.glob(File.join(dir, "*.bru")).map do |f|
          doc = Bruno.parse(File.read(f))
          (doc.block("meta")&.[]("seq") || "0").to_i
        rescue StandardError
          0
        end
        existing.empty? ? 1 : existing.max + 1
      end
    end
  end
end
