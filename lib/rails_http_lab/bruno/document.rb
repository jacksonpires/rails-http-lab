module RailsHttpLab
  module Bruno
    class Document
      attr_accessor :blocks
      attr_accessor :leading_blank_lines, :trailing_newline

      def initialize(blocks: [], leading_blank_lines: 0, trailing_newline: true)
        @blocks              = blocks
        @leading_blank_lines = leading_blank_lines
        @trailing_newline    = trailing_newline
      end

      def block(name)
        blocks.find { |b| b.name == name }
      end

      def blocks_named(name)
        blocks.select { |b| b.name == name }
      end

      VERBS = %w[get post put patch delete head options].freeze

      def verb_block
        blocks.find { |b| VERBS.include?(b.name) }
      end

      def http_method
        verb_block&.name&.upcase
      end

      def url
        verb_block&.[]("url")
      end
    end
  end
end
