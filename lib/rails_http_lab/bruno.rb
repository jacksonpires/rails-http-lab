require "rails_http_lab/bruno/block"
require "rails_http_lab/bruno/document"
require "rails_http_lab/bruno/parser"
require "rails_http_lab/bruno/serializer"

module RailsHttpLab
  module Bruno
    def self.parse(src);   Parser.parse(src);   end
    def self.dump(doc);    Serializer.dump(doc); end
    def self.parse_file(path);  parse(File.read(path)); end
  end
end
