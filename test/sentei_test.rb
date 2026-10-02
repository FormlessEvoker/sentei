require "fileutils"
require "minitest/autorun"
require "open3"
require "stringio"
require "tmpdir"
require_relative "../lib/sentei"

class SenteiTest < Minitest::Test
  def setup
    @directory = Dir.mktmpdir("sentei-test")
    @pandoc_bin = File.join(@directory, "bin")
    FileUtils.mkdir_p(@pandoc_bin)
    @capture = File.join(@directory, "pandoc-input.html")
    pandoc = File.join(@pandoc_bin, "pandoc")
    File.write(pandoc, <<~SCRIPT)
      #!/bin/sh
      if [ "$1" = "--version" ]; then
        echo "pandoc 3.1"
        exit 0
      fi
      cat > "$SENTEI_TEST_CAPTURE"
      printf '# Converted\\n'
    SCRIPT
    FileUtils.chmod(0o755, pandoc)
    @original_path = ENV.fetch("PATH")
    @original_capture = ENV["SENTEI_TEST_CAPTURE"]
    ENV["PATH"] = "#{@pandoc_bin}:#{@original_path}"
    ENV["SENTEI_TEST_CAPTURE"] = @capture
  end

  def teardown
    ENV["PATH"] = @original_path
    ENV["SENTEI_TEST_CAPTURE"] = @original_capture
    FileUtils.remove_entry(@directory)
  end

  def test_extracts_main_and_removes_noncontent_markup
    status, output, error = run_cli([], "<nav>Menu</nav><main><h1>Guide</h1><script>alert(1)</script><p>Text</p></main>")

    assert_equal 0, status
    assert_equal "# Converted\n", output
    assert_empty error
    html = File.read(@capture)
    assert_includes html, "Guide"
    assert_includes html, "Text"
    refute_includes html, "Menu"
    refute_includes html, "alert"
  end

  def test_resolves_relative_links_without_fetching
    status, = run_cli(["--base-url", "https://example.test/docs/"], '<main><a href="../guide">Guide</a></main>')

    assert_equal 0, status
    assert_includes File.read(@capture), 'href="https://example.test/guide"'
  end

  def test_uses_role_main_and_explicit_class_selectors
    status, = run_cli([], '<div role="main"><p>Role content</p></div>')
    assert_equal 0, status
    assert_includes File.read(@capture), "Role content"

    status, = run_cli(["--selector", ".target"], '<div class="target"><p>Selected</p></div>')
    assert_equal 0, status
    assert_includes File.read(@capture), "Selected"
  end

  def test_no_extract_keeps_navigation_but_removes_unsafe_markup
    status, = run_cli(["--no-extract"], "<nav>Navigation</nav><script>unsafe()</script><p>Body</p>")

    assert_equal 0, status
    html = File.read(@capture)
    assert_includes html, "Navigation"
    assert_includes html, "Body"
    refute_includes html, "unsafe"
  end

  def test_rejects_ambiguous_and_invalid_selectors
    status, _output, error = run_cli(["--selector", "article"], "<article>A</article><article>B</article>")
    assert_equal 1, status
    assert_includes error, "must match exactly one"

    status, _output, error = run_cli(["--remove", "["], "<main>Text</main>")
    assert_equal 1, status
    assert_includes error, "Invalid CSS selector"
  end

  def test_rejects_empty_and_non_html_input
    status, = run_cli([], "")
    assert_equal 1, status

    status, _output, error = run_cli([], "just text")
    assert_equal 1, status
    assert_includes error, "does not contain HTML"
  end

  def test_reports_missing_pandoc_without_echoing_document_content
    ENV["PATH"] = File.join(@directory, "empty")
    status, _output, error = run_cli([], "<main>private content</main>")

    assert_equal 3, status
    assert_includes error, "Pandoc is unavailable"
    refute_includes error, "private content"
  ensure
    ENV["PATH"] = "#{@pandoc_bin}:#{@original_path}"
  end

  def test_refuses_to_overwrite_output_without_force
    input = File.join(@directory, "input.html")
    output = File.join(@directory, "output.md")
    File.write(input, "<main>Text</main>")
    File.write(output, "keep me")

    status, _stdout, error = run_file_cli(["--output", output], input)
    assert_equal 4, status
    assert_includes error, "use --force"
    assert_equal "keep me", File.read(output)

    status, = run_file_cli(["--force", "--output", output], input)
    assert_equal 0, status
    assert_equal "# Converted\n", File.read(output)
  end

  def test_never_overwrites_the_input_file
    input = File.join(@directory, "input.html")
    original = "<main>Original</main>"
    File.write(input, original)

    status, _stdout, error = run_file_cli(["--force", "--output", input], input)

    assert_equal 4, status
    assert_includes error, "must not refer to the input"
    assert_equal original, File.read(input)
  end

  private

  def run_cli(arguments, content)
    stdout = StringIO.new
    stderr = StringIO.new
    stdin = StringIO.new(content)
    cli = Sentei::CLI.new(input: stdin, output: stdout, error: stderr)
    [cli.run(arguments + ["--", "-"]), stdout.string, stderr.string]
  end

  def run_file_cli(arguments, path)
    stdout = StringIO.new
    stderr = StringIO.new
    cli = Sentei::CLI.new(output: stdout, error: stderr)
    [cli.run(arguments + [path]), stdout.string, stderr.string]
  end
end
