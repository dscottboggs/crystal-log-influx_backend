require "log"
require "http/client"
require "json"
require "./errors"

# require "./line_protocol" moved to end of file

class ::Log
  class InfluxBackend < ::Log::Backend
    Log = ::Log.for "log.influx_backend"

    class Config
      property token : String,
        org : String,
        bucket : String,
        location : URI

      def initialize(@token, @org, @bucket, @location); end

      property params : String do
        URI::Params.encode({
          org:       org,
          bucket:    bucket,
          precision: "ms", # hardcoded
        })
      end
    end

    property client : HTTP::Client, config : Config

    delegate :params, to: config

    def self.new(token : String,
                 org : String,
                 bucket : String,
                 location : String | URI = "localhost:8086",
                 dispatcher : ::Log::Dispatcher | ::Log::DispatchMode = :async)
      new dispatcher: dispatcher,
        config: Config.new token, org, bucket,
          case location
          in String then URI.parse location
          in URI    then location
          end
    end

    def initialize(@config : Config, dispatcher : ::Log::Dispatcher | ::Log::DispatchMode = :async)
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
      body = LineProtocol.build_body entry
      loc = "/api/v2/write?#{params}"
      Log.trace &.emit "sending write request to InfluxDB", location: loc, body: body
      response = client.post loc, body: body
      body = response.body_io?.try(&.gets_to_end) || response.body? || "(no body received in response)"
      if response.success?
        Log.debug &.emit "write successful", status: response.status.to_s, response: body
      else
        # in case there are other configured loggers
        Log.fatal &.emit "write unsuccessful!", status: response.status.to_s, response: body
        raise Influx::APIError.for_status response.status, body
      end
    end
  end
end

require "./line_protocol"
