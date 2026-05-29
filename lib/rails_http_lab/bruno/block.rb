module RailsHttpLab
  module Bruno
    class Block
      MODES = %i[kv raw].freeze

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
        else
          { raw: raw }
        end
      end
    end
  end
end
