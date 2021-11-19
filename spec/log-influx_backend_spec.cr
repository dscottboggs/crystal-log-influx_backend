require "yaml"
require "./spec_helper"
require "../src/log-influx_backend"

config = File.open "spec-config.yml", &->YAML.parse(File)

query_headers = HTTP::Headers.new.merge!({
  "Content-Type" => "application/vnd.flux",
  "Accept"       => "application/csv",
})

class ::Log
  describe InfluxBackend do
    it "writes data to the database" do
      start = Time.utc
      backend = InfluxBackend.new config["token"].as_s,
        config["org"].as_s,
        config["bucket"].as_s,
        config["location"]?.try(&.as_s) || "http://localhost:8086/"
      entry = Entry.new source: "log.influx_backend.spec",
        severity: :info,
        message: "test log entry",
        data: Metadata.build({test: "data"}),
        exception: nil
      backend.write entry
      sleep 0.1 # allow influx time to write the data...Influx writes are async
      # so there isn't really a better way to handle this.

      # params for read query
      params = URI::Params.encode({
        org: backend.config.org,
      })

      # read written data from the db
      result = backend.client.post "/api/v2/query?#{params}",
        headers: query_headers,
        body: %[
          from(bucket: "#{backend.config.bucket}")
            |>range(start: #{start.to_rfc3339})
        ]
      body = result.body? || result.body_io?.try &.gets_to_end
      result.success?.should be_true
      body.should_not be_nil

      # check the contents of the query result for the expected values
      lines = body.not_nil!.split "\r\n"
      lines.size.should eq 5
      lines[0].should eq ",result,table,_start,_stop,_time,_value,_field,_measurement,context,severity"
      lines[1..2].each do |line|
        columns = line.split ','
        columns.size.should eq 11
        %w[message test].should contain columns[7]
        columns[6].should eq "test log entry" if columns[7] == "message"
        columns[6].should eq "data" if columns[7] == "test"
      end
      lines[3].empty?.should be_true
      lines[4].empty?.should be_true

      # if we've gotten this far, might as well clean up after the successful run.
      result = backend.client.post "/api/v2/delete?#{URI::Params.encode({"bucket" => backend.config.bucket, "org" => backend.config.org})}",
        headers: HTTP::Headers.new.merge!({"Content-Type" => "applicaiton/json"}),
        body: {start: start.to_rfc3339, stop: Time.utc.to_rfc3339}.to_json
      result.success?.should be_true
      result.body.empty?.should be_true
    end
  end
end
