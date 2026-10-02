# frozen_string_literal: true

require "test_helper"

class DocumentTest < Minitest::Test
  def test_returns_complete_body
    html = Sentei::Document.new(File.binread(fixture_path("basic.html"))).body_html

    assert_match(/\A<body>/, html)
    assert_includes html, "<h1>Widget Guide</h1>"
    refute_includes html, "<title>"
  end

  def test_serializes_as_utf8
    html = Sentei::Document.new("<p>caf\xC3\xA9</p>".b).body_html

    assert_equal Encoding::UTF_8, html.encoding
    assert_includes html, "café"
  end

  def test_honors_declared_legacy_encoding
    html = Sentei::Document.new("<meta charset=windows-1252><p>caf\xE9</p>".b).body_html

    assert_includes html, "café"
  end

  def test_rejects_document_without_body
    assert_raises(Sentei::InputError) do
      Sentei::Document.new("<frameset><frame></frameset>").body_html
    end
  end

  def test_missing_nokogiri_is_a_dependency_error
    error = assert_raises(Sentei::DependencyError) do
      Sentei::Document.load_parser(require_with: ->(_name) { raise LoadError })
    end

    assert_match(/Nokogiri/, error.message)
  end
end
