# InfluxDB backend for Crystal's Logger
The Crystal standard library contains a configurable logging mechanism. This
allows that to be output to InfluxDB.

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     log-influx_backend:
       github: dscottboggs/crystal-log-influx_backend
   ```

2. Run `shards install`

## Usage

```crystal 
require "log"
require "log-influx_backend"

Log.setup backend: Log::InfluxBackend.new token: "your config token",
  org: "your organization",
  bucket: "some bucket"

Log.info &.emit "a log message!", cpu_count: System.cpu_count
```

The log entry's severity, context, and source are formatted as "tags", while
the log message and any metadata are logged as fields.

## Development
### Running tests
Before the integration test will run, you need to write a config file in the
project directory.

```
cat <<-YAML > spec-config.yml
token: (your API token goes here -- found in /etc/influxdb2/influx-configs wherever the influx service is running)
org: some-org
bucket: log-influx_backend.spec

YAML
```

## Contributing

1. Fork it (<https://github.com/dscottboggs/log-influx_backend/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [D. Scott Boggs](https://github.com/dscottboggs) - creator and maintainer
