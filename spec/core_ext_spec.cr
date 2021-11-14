require "./spec_helper"
require "../src/core_ext"

describe Nil do
  it "formats to json null" do
    nil.to_json.should eq "null"
    JSON.build { |b| nil.to_json b }.should eq "null"
  end
end

describe Time do
  it "formats as a RFC3339 timestamp string" do
    Time::UNIX_EPOCH.to_json.should eq %<"1970-01-01T00:00:00Z">
    JSON.build { |b| Time::UNIX_EPOCH.to_json b }.should eq %<"1970-01-01T00:00:00Z">
  end
end
