require "net/http"
require "uri"
require "json"
require "rails_http_lab/execution/variable_resolver"
require "rails_http_lab/execution/response"

module RailsHttpLab
  module Execution
    # Executes a Bruno::Document as an HTTP request, returning Response.
    #
    # Pipeline:
    #   1. Resolve {{vars}} in url, headers, query, body, auth fields.
    #   2. Build query string from params:query (merge with URL query).
    #   3. Build Net::HTTP::<Verb>.
    #   4. Apply auth (bearer/basic/apikey).
    #   5. Set body per body:<type>.
    #   6. Dispatch with timeout, capture timings + size.
    class Runner
      VERBS = {
        "get"     => Net::HTTP::Get,
        "post"    => Net::HTTP::Post,
        "put"     => Net::HTTP::Put,
        "patch"   => Net::HTTP::Patch,
        "delete"  => Net::HTTP::Delete,
        "head"    => Net::HTTP::Head,
        "options" => Net::HTTP::Options
      }.freeze

      def initialize(document, resolver: VariableResolver.new, timeout: nil, max_body: nil)
        @doc      = document
        @resolver = resolver
        @timeout  = timeout  || RailsHttpLab.config.executor_timeout
        @max_body = max_body || RailsHttpLab.config.executor_max_body
      end

      def run
        verb_block = @doc.verb_block
        raise Error, "no HTTP verb block in document" unless verb_block

        sent_request = nil

        url      = @resolver.resolve(verb_block["url"].to_s)
        body_kind = verb_block["body"].to_s
        auth_kind = verb_block["auth"].to_s

        uri = URI.parse(url)
        merge_query!(uri)

        klass = VERBS.fetch(verb_block.name)
        request = klass.new(uri.request_uri)

        apply_headers!(request)
        apply_auth!(request, auth_kind)
        apply_body!(request, body_kind)

        sent_request = summarize_request(request, uri)
        dispatch(uri, request, sent_request)
      rescue URI::InvalidURIError => e
        Response.new(error: "Invalid URL: #{e.message}", request: sent_request)
      rescue Net::OpenTimeout, Net::ReadTimeout => e
        Response.new(error: "Timeout: #{e.message}", request: sent_request)
      rescue StandardError => e
        Response.new(error: "#{e.class}: #{e.message}", request: sent_request)
      end

      private

      def dispatch(uri, request, sent_request)
        started = monotonic_now
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl     = uri.scheme == "https"
        http.open_timeout = @timeout
        http.read_timeout = @timeout

        resp = http.request(request)
        body = resp.body.to_s
        body = body[0, @max_body] + "\n[...truncated]" if body.bytesize > @max_body

        Response.new(
          status:      resp.code.to_i,
          headers:     resp.each_header.to_h,
          body:        body,
          duration_ms: ((monotonic_now - started) * 1000).round,
          size_bytes:  resp.body.to_s.bytesize,
          request:     sent_request
        )
      end

      # Captures the resolved request after all headers/auth/body have been
      # applied so the UI can show an equivalent cURL command.
      def summarize_request(request, uri)
        headers = {}
        request.each_header { |k, v| headers[k] = v }
        {
          method:  request.method.to_s.upcase,
          url:     uri.to_s,
          headers: headers,
          body:    request.body
        }
      end

      def monotonic_now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def merge_query!(uri)
        params_block = @doc.block("params:query") || @doc.block("query")
        return unless params_block&.kv?

        existing = uri.query.to_s
        extra    = params_block.pairs.reject { |k, _| k.start_with?("~") }.map do |k, v|
          "#{URI.encode_www_form_component(k)}=#{URI.encode_www_form_component(@resolver.resolve(v.to_s))}"
        end
        merged = [existing, extra.join("&")].reject(&:empty?).join("&")
        uri.query = merged unless merged.empty?
      end

      def apply_headers!(request)
        block = @doc.block("headers")
        return unless block&.kv?
        block.pairs.each do |k, v|
          next if k.start_with?("~")
          request[k] = @resolver.resolve(v.to_s)
        end
      end

      def apply_auth!(request, kind)
        case kind
        when "bearer"
          token = @resolver.resolve(@doc.block("auth:bearer")&.[]("token").to_s)
          request["Authorization"] = "Bearer #{token}" unless token.empty?
        when "basic"
          user = @resolver.resolve(@doc.block("auth:basic")&.[]("username").to_s)
          pass = @resolver.resolve(@doc.block("auth:basic")&.[]("password").to_s)
          request.basic_auth(user, pass)
        when "apikey"
          block = @doc.block("auth:apikey")
          return unless block
          key = @resolver.resolve(block["key"].to_s)
          val = @resolver.resolve(block["value"].to_s)
          placement = block["placement"].to_s
          if placement == "queryparams"
            uri = request.uri || URI.parse("")
            # placement in query is handled at URL level; skip here
          else
            request[key] = val unless key.empty?
          end
        end
      end

      def apply_body!(request, kind)
        case kind
        when "json"
          raw = @doc.block("body:json")&.raw.to_s
          request.body = @resolver.resolve(raw.strip)
          request["Content-Type"] ||= "application/json"
        when "text"
          request.body = @resolver.resolve(@doc.block("body:text")&.raw.to_s)
          request["Content-Type"] ||= "text/plain"
        when "xml"
          request.body = @resolver.resolve(@doc.block("body:xml")&.raw.to_s)
          request["Content-Type"] ||= "application/xml"
        when "formUrlEncoded", "form-urlencoded"
          block = @doc.block("body:form-urlencoded")
          if block&.kv?
            pairs = block.pairs.reject { |k, _| k.start_with?("~") }
            request.set_form_data(pairs.to_h.transform_values { |v| @resolver.resolve(v.to_s) })
          end
        when "multipartForm", "multipart-form"
          # v1: text fields only.
          block = @doc.block("body:multipart-form")
          if block&.kv?
            pairs = block.pairs.reject { |k, _| k.start_with?("~") }
            request.set_form(pairs.map { |k, v| [k, @resolver.resolve(v.to_s)] }, "multipart/form-data")
          end
        when "graphql"
          query     = @doc.block("body:graphql")&.raw.to_s
          variables = @doc.block("body:graphql:vars")&.raw.to_s
          payload   = { "query" => query }
          payload["variables"] = JSON.parse(variables) rescue payload["variables"] = variables if !variables.empty?
          request.body = JSON.generate(payload)
          request["Content-Type"] ||= "application/json"
        end
      end
    end
  end
end
