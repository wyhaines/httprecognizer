require 'test_helper'

class HttpRecognizerTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::HttpRecognizer::VERSION
  end

  def test_it_detects_everything_from_one_big_chunk
    content = "This is a test.\n"
    http = "GET /index.html HTTP/1.1\r\nHost: test.devnull.com\r\nConnection: Keep-Alive\r\nEtag: ab788a046ac8c135891669d8531d6fa9\r\n\r\n#{content}"
    rec = ::HttpRecognizer.new

    assert !rec.done_parsing?

    rec.receive_data http

    assert rec.done_parsing?
    assert_equal rec.uri, "/index.html"
    assert_equal rec.unparsed_uri, "/index.html"
    assert_equal rec.name, :"test.devnull.com"
    assert_equal rec.request_method, "GET"
    assert_equal rec.http_version, "1.1"
  end

  def test_it_detects_everything_from_many_small_chunks
    content = "This is a test.\n"
    http = "GET /index.html HTTP/1.1\r\nHost: test.devnull.com\r\nConnection: Keep-Alive\r\nEtag: ab788a046ac8c135891669d8531d6fa9\r\n\r\n#{content}"
    http_chunks = http.scan(/......../m)

    rec = ::HttpRecognizer.new

    while !rec.done_parsing? do
      rec.receive_data http_chunks.shift
    end

    assert rec.done_parsing?
    assert_equal rec.uri, "/index.html"
    assert_equal rec.unparsed_uri, "/index.html"
    assert_equal rec.name, :"test.devnull.com"
    assert_equal rec.request_method, "GET"
    assert_equal rec.http_version, "1.1"
  end

end
