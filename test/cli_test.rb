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

  def with_tmpdir
    Dir.mktmpdir("sentei out") { |dir| yield dir }
  end

  def test_output_writes_file_and_leaves_stdout_empty
    require_pandoc

    with_tmpdir do |dir|
      out = File.join(dir, "saved page.md")
      status, stdout, stderr = run_cli("--output", out, fixture_path("basic.html"))

      assert_equal 0, status
      assert_empty stdout
      assert_empty stderr
      assert_equal run_cli(fixture_path("basic.html"))[1], File.read(out, encoding: "UTF-8")
    end
  end

  def test_output_refuses_existing_file_with_exit_4_and_runs_no_conversion
    with_tmpdir do |dir|
      out = File.join(dir, "page.md")
      File.write(out, "keep me")
      pandoc = Object.new
      pandoc.define_singleton_method(:convert) { |_| flunk "converted despite existing output" }

      status, _, stderr = run_cli("-o", out, fixture_path("basic.html"), pandoc: pandoc)

      assert_equal 4, status
      assert_match(/use --force/, stderr)
      assert_equal "keep me", File.read(out)
    end
  end

  def test_force_replaces_existing_output
    require_pandoc

    with_tmpdir do |dir|
      out = File.join(dir, "page.md")
      File.write(out, "old")

      status, = run_cli("-o", out, "--force", fixture_path("basic.html"))

      assert_equal 0, status
      assert_includes File.read(out), "# Widget Guide"
    end
  end

  def test_force_never_replaces_the_input_file
    with_tmpdir do |dir|
      input = File.join(dir, "page.html")
      File.write(input, "<p>Hello</p>")

      status, _, stderr = run_cli("-o", input, "--force", input)

      assert_equal 4, status
      assert_match(/is the input file/, stderr)
      assert_equal "<p>Hello</p>", File.read(input)
    end
  end

  def test_output_race_between_check_and_write_does_not_clobber
    require_pandoc

    with_tmpdir do |dir|
      out = File.join(dir, "page.md")
      racing = Object.new
      real = Sentei::Pandoc.new
      racing.define_singleton_method(:convert) do |html|
        File.write(out, "winner")
        real.convert(html)
      end

      status, = run_cli("-o", out, fixture_path("basic.html"), pandoc: racing)

      assert_equal 4, status
      assert_equal "winner", File.read(out)
      assert_empty Dir.children(dir).grep(/\.tmp\z/)
    end
  end

  def test_failed_conversion_leaves_no_output_file
    with_tmpdir do |dir|
      out = File.join(dir, "page.md")
      pandoc = Sentei::Pandoc.new(executable: support_path("fake_pandoc_failure"))

      status, = run_cli("-o", out, fixture_path("basic.html"), pandoc: pandoc)

      assert_equal 3, status
      assert_empty Dir.children(dir)
    end
  end

  def test_output_to_missing_directory_exits_4
    pandoc = Object.new
    pandoc.define_singleton_method(:convert) { |_| "converted\n" }

    status, _, stderr = run_cli("-o", "/nonexistent-sentei-dir/out.md", fixture_path("basic.html"), pandoc: pandoc)

    assert_equal 4, status
    assert_match(/directory does not exist/, stderr)
  end

  def test_force_without_output_exits_1
    status, _, stderr = run_cli("--force", fixture_path("basic.html"))

    assert_equal 1, status
    assert_match(/--force requires --output/, stderr)
  end

  def test_empty_output_path_exits_1
    assert_equal 1, run_cli("-o", "", fixture_path("basic.html")).first
  end

  def test_oversized_input_exits_1
    status, stdout, stderr = run_cli("-", stdin: "x" * (Sentei::InputReader::MAX_BYTES + 1))

    assert_equal 1, status
    assert_empty stdout
    assert_equal "sentei: input exceeds the maximum size of 10 MiB\n", stderr
  end

  def test_exit_status_mapping
    {
      Sentei::InputError => 1, Sentei::SelectorError => 1, Sentei::ExtractionError => 2,
      Sentei::DependencyError => 3, Sentei::ConversionError => 3, Sentei::OutputError => 4
    }.each do |error, expected|
      pandoc = Object.new
      pandoc.define_singleton_method(:convert) { |_| raise error, "boom" }

      status, _, stderr = run_cli(fixture_path("basic.html"), pandoc: pandoc)

      assert_equal expected, status, error.name
      assert_equal "sentei: boom\n", stderr
    end
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
