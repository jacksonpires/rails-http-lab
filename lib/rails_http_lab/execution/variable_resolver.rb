module RailsHttpLab
  module Execution
    # Replaces {{var}} with the value from a flat hash of variables.
    # Unknown vars are left as-is so the user can see what's missing.
    class VariableResolver
      VAR_RE = /\{\{\s*([\w.-]+)\s*\}\}/

      def initialize(vars = {})
        @vars = stringify_keys(vars)
      end

      def resolve(str)
        return str unless str.is_a?(String)
        str.gsub(VAR_RE) { |m| @vars.fetch(Regexp.last_match(1), m) }
      end

      def self.from_environment_document(doc)
        return new({}) unless doc
        pairs = doc.block("vars")&.pairs || []
        new(pairs.to_h)
      end

      private

      def stringify_keys(h)
        h.each_with_object({}) { |(k, v), acc| acc[k.to_s] = v.to_s }
      end
    end
  end
end
