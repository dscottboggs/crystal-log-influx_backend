require "./core_ext"
require "./log-influx_backend"

module ::Log::InfluxBackend::LineProtocol
  extend self

  def build_body(entry)
    String.build do |body|
      body << (measurement_escape entry.source) << ',' \
        << "severity=" << entry.severity << ',' \
        << "context="
      body << tag_escape entry.context.to_json
      body << ' '
      body << "message="
      format_field body, entry.message
      entry.data.each do |key, value|
        body << ','
        body << tag_escape key
        body << '='
        format_field body, value
      end
      body << ' ' << entry.timestamp.to_unix_ms
    end
  end

  def measurement_escape(text : String) : String
    String.build do |str|
      text.each_char do |char|
        str << '\\' if ", ".includes? char
        str << filter_newline char
      end
    end
  end

  def tag_escape(value : Symbol) : String
    tag_escape value.to_s
  end

  def tag_escape(value : String) : String
    String.build do |str|
      value.each_char do |char|
        str << '\\' if "=, ".includes? char
        str << filter_newline char
      end
    end
  end

  def filter_newline(char)
    case char
    when '\n' then %q(\n)
    when '\r' then ""
    else           char
    end
  end

  def format_field(io : IO, value)
    case value
    in ::Log::Metadata::Value then format_field io, value.raw
    in Bool, Float32, Float64 then value.to_s io
    in Time                   then value.to_rfc3339 io
    in String                 then value.to_json io
      # ^^ JSON conveniently escapes this in the ways it would need to be
    in Nil
    in Int32, Int64
      value.to_i64.to_s io
      io << 'i'
    in Array, Hash
      # same with convenient JSON escaping here, by converting to JSON twice.
      format_field io, value.to_json
    end
  end
end
