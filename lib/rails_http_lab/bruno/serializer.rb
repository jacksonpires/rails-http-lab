module RailsHttpLab
  module Bruno
    # Round-trip-stable serializer for Bruno documents.
    #
    # Format per block:
    #
    #   <name> {
    #     key: value
    #   }
    #
    # Raw blocks emit their `raw` content verbatim between '{' and '}'.
    # Blocks are separated by a single blank line, matching Bruno's output.
    class Serializer
      def self.dump(document)
        new(document).dump
      end

      def initialize(document)
        @document = document
      end

      def dump
        out = +""
        out << ("\n" * @document.leading_blank_lines)

        @document.blocks.each_with_index do |block, idx|
          out << "\n" if idx > 0
          out << render_block(block)
        end

        if @document.trailing_newline && !out.end_with?("\n")
          out << "\n"
        elsif !@document.trailing_newline && out.end_with?("\n")
          out.chomp!
        end

        out
      end

      private

      def render_block(block)
        case block.mode
        when :kv  then render_kv(block)
        when :raw then render_raw(block)
        end
      end

      def render_kv(block)
        lines = +"#{block.name} {\n"
        block.pairs.each do |k, v|
          lines << "  #{k}: #{v}\n"
        end
        lines << "}\n"
        lines
      end

      def render_raw(block)
        body = block.raw.to_s
        out = +"#{block.name} {\n"
        out << body
        out << "\n" unless body.empty? || body.end_with?("\n")
        out << "}\n"
        out
      end
    end
  end
end
