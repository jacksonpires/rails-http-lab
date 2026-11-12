module RailsHttpLab
  module Bruno
    class Block
      # :kv   — `name {` + `key: value` lines
      # :raw  — `name {` + opaque body, verbatim
      # :list — `name [` + one item per line (e.g. Bruno's `vars:secret [`),
      #         body kept verbatim in `raw` for byte-stable round-trip
      MODES = %i[kv raw list].freeze

      attr_accessor :name, :mode, :pairs, :raw

      def initialize(name:, mode:, pairs: nil, raw: nil)
        raise ArgumentError, "invalid mode: #{mode}" unless MODES.include?(mode)
        @name  = name
        @mode  = mode
        @pairs = pairs || []
        @raw   = raw
      end

      def kv?;  mode == :kv;  end
      def raw?; mode == :raw; end
      def list?; mode == :list; end

      # Item names of a :list block. Bruno separates items with ",\n".
      def items
        return [] unless list?
        raw.to_s.split("\n").map { |l| l.strip.delete_suffix(",").strip }.reject(&:empty?)
      end

      def [](key)
        return nil unless kv?
        found = pairs.find { |k, _| k == key }
        found && found[1]
      end

      def []=(key, value)
        return unless kv?
        existing = pairs.find { |k, _| k == key }
        if existing
          existing[1] = value
        else
          pairs << [key, value]
        end
      end

      def to_h
        if kv?
          pairs.to_h
        elsif list?
          { items: items }
        else
          { raw: raw }
        end
      end
    end
  end
end
