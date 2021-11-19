module Influx
  class Exception < ::Exception; end

  class APIError < Exception
    property status : HTTP::Status

    def initialize(@status, message, cause = nil)
      super message, cause: cause
    end

    def self.for_status(status, body)
      case status
      when .bad_request?       then BadRequest.new status, body
      when .unauthorized?      then Unauthorized.new status, body
      when .not_found?         then NotFound.new status, body
      when .payload_too_large? then PayloadTooLarge.new status, body
      else                          UnexpectedErrorResponse.new status, body
      end
    end
  end

  class KnownAPIError < APIError
    property code : String, err : String?, op : String?

    def initialize(@status, message, @code, @err = nil, @op = nil, cause = nil)
      super status, message, cause: cause
    end

    macro initizalize_from_fields(*fields)
        def self.new(status, body, *, cause = nil)
          %info = JSON.parse body
          puts({status: status, body: %info})
          new(status, {% for field in fields %}{% if field.type.stringify.ends_with? "::Nil" %}
              {{field.var}}: %info["{{field.var[-1..-1]}}"]?.try(&.raw.as {{field.type}}){% else %}
              {{field.var}}: %info["{{field.var}}"].raw.as({{field.type}}){% end %},
              {% end %}
              cause: cause)
        rescue e : KeyError | TypeCastError
          raise UnexpectedErrorResponse.new status, body, cause: e
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
  class BadRequest < KnownAPIError
    property line : Int32?

    def initialize(@status, message, code, err = nil,
                   line = nil, op = nil, *, cause = nil)
      super status, message, code, err, op, cause: cause
    end

    initizalize_from_fields message : String, code : String, err : String?,
      line : Int32?, op : String?
  end

  # From InfluxDB API docs: Unauthorized. The error may indicate one of the
  # following:
  #  - The `Authorization:` header is missing or malformed.
  #  - The API token value is missing from the header.
  #  - The token does not have sufficient permissions to write to this organization
  #    and bucket.
  class Unauthorized < KnownAPIError
    initizalize_from_fields message : String, code : String, err : String?, op : String?
  end

  class NotFound < KnownAPIError
    initizalize_from_fields message : String, code : String, err : String?, op : String?
  end

  class PayloadTooLarge < KnownAPIError
    initizalize_from_fields message : String, code : String, err : String?, op : String?
  end

  class InternalServerError < KnownAPIError
    initizalize_from_fields message : String, code : String, err : String?, op : String?
  end

  class ServiceUnavailable < Exception
  end
end
