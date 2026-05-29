require "rails_http_lab/bruno/block"
require "rails_http_lab/bruno/document"

module RailsHttpLab
  module Bruno
    # Parses Bruno .bru files into a Document of ordered Blocks.
    #
    # Two content modes:
    #   - :kv  — every line is "  key: value" (2-space indent), one pair per line.
    #   - :raw — opaque body, preserved verbatim. Used for body:json, body:text,
    #            body:xml, body:graphql, body:graphql:vars, body:sparql,
    #            script:pre-request, script:post-response, tests, docs.
    #
    # Round-trip property: Serializer.dump(Parser.parse(s)) == s for files written
    # by Bruno itself (see spec/bruno/round_trip_spec.rb).
    class Parser
      RAW_BLOCK_NAMES = %w[
        body:json
        body:text
        body:xml
        body:sparql
        body:graphql
        body:graphql:vars
        script:pre-request
        script:post-response
        tests
        docs
      ].freeze

      # name = letters/digits/_/- with optional colon-delimited variants
      BLOCK_OPEN_RE = /\A([a-zA-Z][\w-]*(?::[\w-]+)*)\s*\{\s*\z/

      def self.parse(source)
        new(source).parse
      end

      def initialize(source)
        @source = source
        # Split keeping line content; the last element may be "" if source ends with \n.
        @lines = source.split("\n", -1)
        @i     = 0
      end

      def parse
        blocks = []
        leading_blanks = 0

        # Count leading blank lines.
        while @i < @lines.length && blank?(@lines[@i])
          leading_blanks += 1
          @i += 1
        end

        while @i < @lines.length
          line = @lines[@i]

          if blank?(line)
            @i += 1
            next
          end

          if (m = line.match(BLOCK_OPEN_RE))
            name = m[1]
            @i += 1
            if RAW_BLOCK_NAMES.include?(name)
              blocks << parse_raw_block(name)
            else
              blocks << parse_kv_block(name)
            end
          else
            # If we got here we hit something we don't understand. To stay forgiving,
            # skip it; alternatively raise. We raise so callers know their file is off.
            raise ParseError, "unexpected line outside of any block (line #{@i + 1}): #{line.inspect}"
          end
        end

        # Trailing newline preserved iff source ends with \n (then @lines's last entry is "").
        trailing_newline = @source.end_with?("\n")

        Document.new(
          blocks: blocks,
          leading_blank_lines: leading_blanks,
          trailing_newline: trailing_newline
        )
      end

      private

      def blank?(line)
        line.nil? || line.strip.empty?
      end

      def parse_kv_block(name)
        pairs = []
        while @i < @lines.length
          line = @lines[@i]
          if line.strip == "}"
            @i += 1
            return Block.new(name: name, mode: :kv, pairs: pairs)
          end

          if blank?(line)
            @i += 1
            next
          end

          # Parse "  key: value" — first ":" splits. Value may span multiple
          # lines via unbalanced braces (URLs with embedded JSON) or via
          # triple-quoted '''...''' strings (Bruno multi-line literal).
          stripped = line.sub(/\A {0,4}/, "") # tolerate 0-4 leading spaces
          colon_idx = stripped.index(":")
          if colon_idx.nil?
            raise ParseError, "expected 'key: value' in block #{name} at line #{@i + 1}: #{line.inspect}"
          end

          key   = stripped[0...colon_idx]
          value = stripped[(colon_idx + 1)..]
          value = value.sub(/\A /, "") if value
          @i += 1

          value = consume_multiline_value(value, block_name: name)
          pairs << [key, value]
        end

        raise ParseError, "unterminated block #{name.inspect} (missing closing '}')"
      end

      # Returns the (possibly multi-line) value. Continues reading lines while
      # the running brace depth of the value is > 0 OR a '''...''' string is open.
      def consume_multiline_value(value, block_name:)
        while value_needs_continuation?(value)
          if @i >= @lines.length
            raise ParseError, "unterminated multi-line value in block #{block_name.inspect}"
          end
          value = "#{value}\n#{@lines[@i]}"
          @i += 1
        end
        value
      end

      def value_needs_continuation?(value)
        in_triple = false
        depth = 0
        i = 0
        len = value.length
        while i < len
          if value[i, 3] == "'''"
            in_triple = !in_triple
            i += 3
            next
          end
          unless in_triple
            c = value[i]
            depth += 1 if c == "{"
            depth -= 1 if c == "}"
          end
          i += 1
        end
        in_triple || depth > 0
      end

      # Counts braces to find matching '}'. Body content can include arbitrary braces
      # (JSON objects, JS blocks, etc.) so we can't rely on indentation alone.
      def parse_raw_block(name)
        content_lines = []
        depth = 1 # we already consumed the opening '{'

        while @i < @lines.length
          line = @lines[@i]

          # Compute depth change from this line.
          opens  = line.count("{")
          closes = line.count("}")

          # If this line would close the block (depth would reach 0 here),
          # we need to figure out *which* '}' closes it. If the line is exactly "}"
          # (with optional leading whitespace) AND no '{' on the same line AND
          # depth would go to 0, that's the closing brace and isn't part of content.
          if depth + opens - closes <= 0
            # Edge case: closing brace is not alone on its line (mixed content).
            # We try to honor the "alone on a line" convention Bruno uses.
            if line.strip == "}" && opens == 0
              @i += 1
              return Block.new(name: name, mode: :raw, raw: content_lines.join("\n"))
            else
              # Mixed line: we still treat the final '}' as terminator and keep the
              # rest as content. This branch is defensive; real Bruno files don't hit it.
              # Strip the trailing '}' character from the line; everything before it
              # is content. This is best-effort.
              last_brace = line.rindex("}")
              prefix     = line[0...last_brace]
              content_lines << prefix unless prefix.empty?
              @i += 1
              return Block.new(name: name, mode: :raw, raw: content_lines.join("\n"))
            end
          end

          content_lines << line
          depth += opens - closes
          @i += 1
        end

        raise ParseError, "unterminated raw block #{name.inspect}"
      end
    end
  end
end
