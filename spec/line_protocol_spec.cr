require "./spec_helper"
require "../src/line_protocol"

macro test_format_field(value, renders_to expected)
  String.build do |str|
    Log::InfluxBackend::LineProtocol.format_field str, {{value}}
  end.should eq {{expected}}
end

describe ::Log::InfluxBackend::LineProtocol do
  describe ".measurement_escape" do
    it "inserts backslashes before commas and spaces" do
      ::Log::InfluxBackend::LineProtocol.measurement_escape(
        "some = text, why not?"
      ).should eq %q[some\ =\ text\,\ why\ not?]
    end
  end

  describe ".tag_escape" do
    it "inserts backslashes before equals signs, commas, and spaces" do
      ::Log::InfluxBackend::LineProtocol.tag_escape(
        "some = text, why not?"
      ).should eq %q[some\ \=\ text\,\ why\ not?]
    end
    it "works on symbols, too" do
      ::Log::InfluxBackend::LineProtocol.tag_escape(
        :"some = text, why not?"
      ).should eq %q[some\ \=\ text\,\ why\ not?]
    end
  end

  describe ".filter_newline" do
    it "removes carriage returns" do
      ::Log::InfluxBackend::LineProtocol.tag_escape("\r").should eq ""
    end
    it "replaces newlines with \n" do
      ::Log::InfluxBackend::LineProtocol.tag_escape("\n").should eq %q<\n>
    end
  end

  describe ".format_field" do
    it "formats a floating point value" do
      test_format_field 1_f64, renders_to: "1.0"
      test_format_field 1_f32, renders_to: "1.0"
      test_format_field Float64::MAX, renders_to: "1.7976931348623157e+308"
      test_format_field Float64::EPSILON, renders_to: "2.220446049250313e-16"
      test_format_field Float64::NAN, renders_to: "NaN"
      test_format_field Float64::INFINITY, renders_to: "Infinity"
    end

    it "formats a signed integer field" do
      test_format_field 1_i32, renders_to: "1i"
      test_format_field 1_i64, renders_to: "1i"
    end

    it "formats an unsigned integer field" do
      # Log::InfluxBackend.format_field(1_u32).should eq "1u"
      # Log::InfluxBackend.format_field(1_u64).should eq "1u"
    end
    it "formats a boolean value" do
      test_format_field true, renders_to: "true"
      test_format_field false, renders_to: "false"
    end
    it "formats a Time value" do
      test_format_field Time::UNIX_EPOCH, renders_to: "1970-01-01T00:00:00Z"
    end
    it "formats a nil value" do
      test_format_field nil, renders_to: ""
    end
    it "formats a string" do
      test_format_field "test", renders_to: %["test"]
    end
    it "formats an array of values" do
      test_format_field [1], renders_to: %<"[1]">
      test_format_field [1, 2, 3], renders_to: %["[1,2,3]"]
    end
    it "formats a hash table" do
      test_format_field({"one" => 1}, renders_to: %q<"{\"one\":1}">)
    end
    it "formats a Metadata::Value which is a hash table" do
      s : ::Log::Metadata::Value = ::Log::Metadata.build({test: {one: 1, two: 2}})[:test]
      test_format_field s, renders_to: %q["{\"one\":1,\"two\":2}"]
    end
  end
end
