module RailsHttpLab
  module Execution
    Response = Struct.new(
      :status, :headers, :body, :duration_ms, :size_bytes, :error, :request,
      keyword_init: true
    ) do
      def to_h
        {
          status:      status,
          headers:     headers,
          body:        body,
          duration_ms: duration_ms,
          size_bytes:  size_bytes,
          error:       error,
          request:     request
        }
      end
    end
  end
end
