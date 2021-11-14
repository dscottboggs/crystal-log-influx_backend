require "log"
require "http/client"
require "json"
require "./core_ext" # stdlib monkey-patches

class ::Log
  class InfluxBackend < ::Log::Backend
    class Exception < ::Exception; end

    class APIError < Exception
      @[JSON::Field(ignore: true)]
      property status : HTTP::Status, code : String, err : String?, op : String?

      def initialize(@status, message, @code, @err = nil, @op = nil, cause = nil)
        super message, cause: cause
      end

      macro initizalize_from_fields(*fields)
        def self.new(status, body, *, cause = nil)
        info = JSON.parse body
        puts({status: status, body: info})
        new status, {% for field in fields %}
          {% if field.ends_with? "?" %}
            {{field.id}}: info[{{field.stringify[...-1]}}]?,
          {% else %}
            {{field.id}}: info[{{field.stringify}}],
          {% end %}
          cause: cause
        {% end %}
        rescue e : KeyError
          raise UnexpectedErrorResponse.new status, body, cause: e
        end
      end

      def self.for_status(status, body)
        case status
        when :bad_request       then BadRequest.new status, body
        when :unauthorized      then Unauthorized.new status, body
        when :not_found         then NotFound.new status, body
        when :payload_too_large then PayloadTooLarge.new status, body
        else                         UnexpectedErrorResponse.new status, body
        end
      end
    end

    class UnexpectedErrorResponse < APIError
      def initialize(status, body, cause = nil)
        super status,
          "response body for status #{status} was not as expected:\n\n#{body}",
          cause: cause
      end
    end

    # From InfluxDB API docs: Bad request. The line protocol data in the
    # request is malformed. The response body contains the first malformed line
    # in the data. InfluxDB rejected the batch and did not write any data.
    class BadRequest < APIError
      property line : Int32?

      def initialize(@status, message, code, err = nil,
                     line = nil, op = nil, *, cause = nil)
        super status, message, code, err, line, op, cause: cause
      end

      initizalize_from_fields :message, :code, :err?, :line?, :op?
    end

    # From InfluxDB API docs: Unauthorized. The error may indicate one of the
    # following:
    #  - The `Authorization:` header is missing or malformed.
    #  - The API token value is missing from the header.
    #  - The token does not have sufficient permissions to write to this organization
    #    and bucket.
    class Unauthorized < APIError
      initizalize_from_fields :code, :err, :op
    end

    class NotFound < APIError
      initizalize_from_fields :code, :err, :op
    end

    class PayloadTooLarge < APIError
      initizalize_from_fields :code, :err, :op
    end

    class InternalServerError < APIError
      initizalize_from_fields :code, :err, :op
    end

    class ServiceUnavailable < Exception
    end

    class Config
      property token : String,
        org : String,
        bucket : String,
        location : URI

      def params
        URI::Params.encode({
          org:       org,
          bucket:    bucket,
          precision: "ms", # hardcoded
        })
      end
    end

    property client : HTTP::Client, config : Config, location : URI

    def self.new(token : String,
                 org : String,
                 bucket : String,
                 location : String | URI = "localhost:8086",
                 dispatcher = :async)
      new dispatcher: dispatcher,
        config: Config.new token, org, bucket,
          case location
          in String then URI.parse location
          in URI    then location
          end
    end

    def initialize(@config : Config, dispatcher = :async)
      super dispatcher
      @client = HTTP::Client.new @config.location

      client.before_request do |request|
        request.headers["Authorization"] = "Token #{@config.token}"
      end
    end

    def close : Nil
      super
      client.close
    end

    def write(entry : Entry)
      response = client.post "/write?#{params}", body: build_body entry
      unless response.success?
        body = response.body_io? || response.body? || "no body received in response"
        raise APIError.for_status response.status, body
      end
    end

    def build_body(entry)
      String.build do |body|
        body << (measurement_escape entry.source) << ',' \
          << "severity=" << entry.severity << ',' \
          << "context="
        body << tag_escape entry.context.to_json
        body << "message=" << entry.message
        entry.data.each do |key, value|
          body << tag_escape key
          format_field body, value
        end
        body << ' ' << entry.timestamp.to_unix_ms
      end
    end

    def self.measurement_escape(text : String) : String
      String.build do |str|
        text.each_char do |char|
          str << '\\' if ", ".includes? char
          str << char
        end
      end
    end

    def self.tag_escape(value : String) : String
      String.build do |str|
        value.each_char do |char|
          str << '\\' if "=, ".includes? char
          c = case char
              when '\n' then %q(\n)
              when '\r' then ""
              else           char
              end
          str << c
        end
      end
    end

    def self.format_field(io : IO, value)
      case value
      in ::Log::Metadata::Value then format_field io, value.raw
      in Bool, Float32, Float64 then value.to_s io
      in Time                   then value.to_rfc3339 io
      in String                 then value.to_json io
      in Nil
      in Int32, Int64
        value.to_i64.to_s io
        io << 'i'
      in Array, Hash
        format_field io, value.to_json
      end
    end
  end
end
