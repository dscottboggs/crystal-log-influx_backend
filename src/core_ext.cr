require "json/builder"

struct ::Nil
  def to_json(builder : JSON::Builder)
    builder.null
  end
end

struct ::Time
  def to_json(builder : JSON::Builder)
    builder.string to_rfc3339
  end
end

class ::Log
  class Metadata
    struct Value
      def to_json(builder : JSON::Builder)
        raw.to_json builder
      end
    end

    def to_json(builder : JSON::Builder)
      builder.object do
        each do |k, v|
          # key is a Symbol, cast as String
          builder.field k.to_s, v
        end
      end
    end
  end
end
