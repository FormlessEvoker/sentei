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
end
