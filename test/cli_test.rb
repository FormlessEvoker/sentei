# frozen_string_literal: true

require "test_helper"
require "bundler"
require "fileutils"
require "open3"
require "tmpdir"

class CLITest < Minitest::Test
  def run_cli(*argv, stdin: "", pandoc: Sentei::Pandoc.new)
    stdout = StringIO.new
    stderr = StringIO.new
    status = Sentei::CLI.run(argv, stdin: StringIO.new(stdin), stdout: stdout, stderr: stderr, pandoc: pandoc)
    [status, stdout.string, stderr.string]
  end

  def test_converts_file_to_markdown
    require_pandoc

    status, markdown, stderr = run_cli(fixture_path("basic.html"))

    assert_equal 0, status
    assert_empty stderr
    assert_includes markdown, "# Widget Guide\n"
    assert_includes markdown, "### Options\n"
    assert_includes markdown, "1.  Download the widget.\n"
    assert_includes markdown, "- Start a widget\n"
    assert_includes markdown, "[widget reference](https://example.com/widgets)"
    assert_includes markdown, "![Diagram of a widget](images/widget.png)"
    assert_includes markdown, "``` ruby\nwidget = Widget.new(name: \"demo\")\nwidget.start\n```\n"
    assert_includes markdown, "| speed  | normal  |\n"
    assert_includes markdown, "Café-style"
    refute_includes markdown, "<"
  end

  def test_standard_input_matches_file_input
    require_pandoc

    html = File.binread(fixture_path("basic.html"))
    _, from_file, = run_cli(fixture_path("basic.html"))
    status, from_stdin, = run_cli("-", stdin: html)

    assert_equal 0, status
    assert_equal from_file, from_stdin
  end

  def test_missing_input_exits_1
    status, stdout, stderr = run_cli(fixture_path("missing.html"))

    assert_equal 1, status
    assert_empty stdout
    assert_match(/^sentei: input file not found/, stderr)
  end

  def test_empty_standard_input_exits_1
    status, _, stderr = run_cli("-", stdin: "\n")

    assert_equal 1, status
    assert_equal "sentei: input is empty\n", stderr
  end

  def test_requires_exactly_one_input
    assert_equal 1, run_cli.first
    assert_equal 1, run_cli("a.html", "b.html").first
  end

  def test_unknown_option_exits_1
    status, _, stderr = run_cli("--bogus", "x.html")

    assert_equal 1, status
    assert_match(/invalid option: --bogus/, stderr)
  end

  def test_missing_pandoc_exits_3
    pandoc = Sentei::Pandoc.new(executable: support_path("no-such-pandoc"))

    status, stdout, stderr = run_cli(fixture_path("basic.html"), pandoc: pandoc)

    assert_equal 3, status
    assert_empty stdout
    assert_match(/pandoc executable not found/, stderr)
  end

  def test_pandoc_failure_exits_3_without_leaking_content
    pandoc = Sentei::Pandoc.new(executable: support_path("fake_pandoc_failure"))

    status, stdout, stderr = run_cli(fixture_path("basic.html"), pandoc: pandoc)

    assert_equal 3, status
    assert_empty stdout
    refute_includes stderr, "Widget"
  end

  def test_help_and_version
    status, stdout, = run_cli("--help")
    assert_equal 0, status
    assert_match(/Usage: sentei \[options\] INPUT/, stdout)

    status, stdout, = run_cli("-v")
    assert_equal 0, status
    assert_equal "sentei #{Sentei::VERSION}\n", stdout
  end

  def test_executable_converts_path_with_spaces
    require_pandoc

    Dir.mktmpdir("sentei test") do |dir|
      path = File.join(dir, "saved page.html")
      File.write(path, "<p>Hello</p>")
      executable = File.expand_path("../bin/sentei", __dir__)

      stdout, stderr, status = Open3.capture3(executable, path)

      assert status.success?, stderr
      assert_equal "Hello\n", stdout
    end
  end

  # bin/sentei resolves its Gemfile relative to itself, so a copy beside an
  # unsatisfiable Gemfile simulates Bundler failing to load the pinned gems.
  def test_executable_fails_closed_when_pinned_gems_cannot_load
    Dir.mktmpdir("sentei bundler") do |dir|
      FileUtils.mkdir_p(File.join(dir, "bin"))
      executable = File.join(dir, "bin", "sentei")
      FileUtils.cp(File.expand_path("../bin/sentei", __dir__), executable)
      File.write(File.join(dir, "Gemfile"), "source \"https://rubygems.org\"\ngem \"sentei-no-such-gem\"\n")

      # Drop the test run's own Bundler environment (RUBYOPT, BUNDLE_*), which
      # would otherwise fail before the script gets to run.
      _, stderr, status = Bundler.with_unbundled_env { Open3.capture3(executable, "-") }

      assert_equal 3, status.exitstatus
      assert_match(/could not load Sentei's pinned gems/, stderr)
      assert_match(/sentei-no-such-gem/, stderr)
    end
  end

  # Bundler cannot switch Gemfiles once another is active, so bin/sentei must
  # shed an inherited environment rather than trust Bundler.setup to replace it.
  def test_executable_ignores_another_projects_bundle
    require_pandoc

    Dir.mktmpdir("sentei other") do |dir|
      File.write(File.join(dir, "Gemfile"), "source \"https://rubygems.org\"\n")
      File.write(File.join(dir, "page.html"), "<p>Hello</p>")
      executable = File.expand_path("../bin/sentei", __dir__)

      stdout, stderr, status = Bundler.with_unbundled_env do
        env = { "BUNDLE_GEMFILE" => File.join(dir, "Gemfile") }
        Open3.capture3(env, "bundle", "exec", executable, File.join(dir, "page.html"), chdir: dir)
      end

      assert status.success?, stderr
      assert_equal "Hello\n", stdout
    end
  end
end
