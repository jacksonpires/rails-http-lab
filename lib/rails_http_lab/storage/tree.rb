require "pathname"

module RailsHttpLab
  module Storage
    # Builds a hierarchical view of the storage root for the sidebar.
    # Returns:
    #   {
    #     name: "My APIs",
    #     type: "collection",
    #     children: [
    #       { type: "folder", name: "...", path: "...", children: [...] },
    #       { type: "request", name: "...", path: "...", method: "GET", seq: 1 }
    #     ],
    #     environments: [{ name: "Local", path: "environments/Local.bru" }]
    #   }
    class Tree
      def initialize(root: RailsHttpLab.config.resolved_storage_path)
        @root = Pathname.new(root.to_s)
      end

      def build
        return empty_tree unless @root.directory?

        collection = read_collection_manifest
        children   = list_children(@root, relative_prefix: "")
        envs       = list_environments

        {
          name:         collection["name"] || @root.basename.to_s,
          type:         "collection",
          children:     children,
          environments: envs
        }
      end

      private

      def empty_tree
        { name: "(missing)", type: "collection", children: [], environments: [] }
      end

      def read_collection_manifest
        f = @root + "bruno.json"
        return {} unless f.file?
        JSON.parse(f.read)
      rescue JSON::ParserError
        {}
      end

      def list_children(dir, relative_prefix:)
        return [] unless dir.directory?

        entries = dir.children.sort_by { |c| c.basename.to_s.downcase }
        out = []

        entries.each do |child|
          rel = relative_prefix.empty? ? child.basename.to_s : "#{relative_prefix}/#{child.basename}"

          if child.directory?
            next if child.basename.to_s == "environments" && relative_prefix.empty?
            folder_meta = read_folder_meta(child)
            out << {
              type:     "folder",
              name:     folder_meta[:name] || child.basename.to_s,
              path:     rel,
              seq:      folder_meta[:seq],
              children: list_children(child, relative_prefix: rel)
            }
          elsif child.file? && child.extname == ".bru" && child.basename.to_s != "folder.bru"
            meta = read_request_meta(child)
            out << {
              type:   "request",
              name:   meta[:name] || child.basename(".bru").to_s,
              path:   rel,
              method: meta[:method],
              seq:    meta[:seq]
            }
          end
        end

        # Top-level entries (collections) are always alphabetical.
        # Nested entries respect Bruno's seq ordering, falling back to name.
        if relative_prefix.empty?
          out.sort_by { |c| c[:name].to_s.downcase }
        else
          out.sort_by { |c| [c[:seq] || 9999, c[:name].to_s.downcase] }
        end
      end

      def list_environments
        envs_dir = @root + "environments"
        return [] unless envs_dir.directory?
        envs_dir.children.select { |c| c.file? && c.extname == ".bru" }.map do |f|
          { name: f.basename(".bru").to_s, path: "environments/#{f.basename}" }
        end.sort_by { |e| e[:name].downcase }
      end

      def read_folder_meta(dir)
        f = dir + "folder.bru"
        return {} unless f.file?
        doc  = Bruno.parse(f.read)
        meta = doc.block("meta")
        return {} unless meta
        { name: meta["name"], seq: meta["seq"]&.to_i }
      rescue StandardError
        {}
      end

      def read_request_meta(file)
        doc    = Bruno.parse(file.read)
        meta   = doc.block("meta")
        method = doc.http_method
        return { method: method } unless meta
        { name: meta["name"], seq: meta["seq"]&.to_i, method: method }
      rescue StandardError
        { method: nil }
      end
    end
  end
end
