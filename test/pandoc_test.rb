# frozen_string_literal: true

require "test_helper"

class PandocTest < Minitest::Test
  def test_converts_html_to_gfm
    require_pandoc

    markdown = Sentei::Pandoc.new.convert("<body><h2>Title</h2><pre><code>x &lt; y</code></pre></body>")

    assert_equal "## Title\n\n```\nx < y\n```\n", markdown
    assert_equal Encoding::UTF_8, markdown.encoding
  end

  def test_fence_outlasts_backticks_in_code
    require_pandoc

    markdown = Sentei::Pandoc.new.convert("<pre><code>a ``` b</code></pre>")

    assert_equal "````\na ``` b\n````\n", markdown
  end

  def test_fences_empty_code_block
    require_pandoc

    assert_equal "```\n```\n", Sentei::Pandoc.new.convert("<pre><code></code></pre>")
  end

  def test_missing_executable_is_a_dependency_error
    pandoc = Sentei::Pandoc.new(executable: support_path("no-such-pandoc"))

    error = assert_raises(Sentei::DependencyError) { pandoc.convert("<p>x</p>") }

    assert_match(/not found/, error.message)
  end

  def test_failure_reports_status_without_document_content
    pandoc = Sentei::Pandoc.new(executable: support_path("fake_pandoc_failure"))

    error = assert_raises(Sentei::ConversionError) { pandoc.convert("<p>confidential text</p>") }

    assert_equal "pandoc failed with exit status 64", error.message
  end
end
