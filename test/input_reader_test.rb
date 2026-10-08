# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class InputReaderTest < Minitest::Test
  def reader(stdin = StringIO.new)
    Sentei::InputReader.new(stdin: stdin)
  end

  def test_reads_file_bytes
    expected = File.binread(fixture_path("basic.html"))

    assert_equal expected, reader.read(fixture_path("basic.html"))
  end

  def test_reads_standard_input_for_dash
    assert_equal "<p>hi</p>", reader(StringIO.new("<p>hi</p>")).read("-")
  end

  def test_rejects_missing_file
    error = assert_raises(Sentei::InputError) { reader.read(fixture_path("missing.html")) }

    assert_match(/not found/, error.message)
  end

  def test_rejects_directory
    error = assert_raises(Sentei::InputError) { reader.read(FIXTURES) }

    assert_match(/directory/, error.message)
  end

  def test_rejects_empty_file
    Dir.mktmpdir do |dir|
      path = File.join(dir, "empty.html")
      File.write(path, "")

      assert_raises(Sentei::InputError) { reader.read(path) }
    end
  end

  def test_rejects_whitespace_only_standard_input
    error = assert_raises(Sentei::InputError) { reader(StringIO.new(" \n\t\r\n")).read("-") }

    assert_equal "input is empty", error.message
  end

  def test_accepts_input_exactly_at_the_limit
    limited = Sentei::InputReader.new(stdin: StringIO.new("<p>1234</p>"), max_bytes: 11)

    assert_equal "<p>1234</p>", limited.read("-")
  end

  def test_rejects_oversized_standard_input
    limited = Sentei::InputReader.new(stdin: StringIO.new("<p>12345</p>"), max_bytes: 11)

    error = assert_raises(Sentei::InputError) { limited.read("-") }

    assert_equal "input exceeds the maximum size of 11 bytes", error.message
  end

  def test_rejects_oversized_file_without_reading_it_all
    Dir.mktmpdir do |dir|
      path = File.join(dir, "big.html")
      File.write(path, "<p>#{"x" * 100}</p>")
      limited = Sentei::InputReader.new(stdin: StringIO.new, max_bytes: 50)

      error = assert_raises(Sentei::InputError) { limited.read(path) }

      assert_match(/exceeds the maximum size/, error.message)
    end
  end

  def test_default_limit_is_10_mib
    assert_equal 10 * 1024 * 1024, Sentei::InputReader::MAX_BYTES

    error = assert_raises(Sentei::InputError) { reader(StringIO.new("x" * (10 * 1024 * 1024 + 1))).read("-") }

    assert_equal "input exceeds the maximum size of 10 MiB", error.message
  end
end
