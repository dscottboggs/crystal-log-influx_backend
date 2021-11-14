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

struct ::Log::Metadata::Value
  def to_json(builder : JSON::Builder)
    raw.to_json builder
  end
end
