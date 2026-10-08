# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class OutputWriterTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir("sentei output")
    @stdout = StringIO.new
    @writer = Sentei::OutputWriter.new(stdout: @stdout)
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def path(name = "page.md")
    File.join(@dir, name)
  end

  def leftovers
    Dir.children(@dir).grep(/\.tmp\z/)
  end

  # Replaces a File singleton method for the block, then restores it.
  def with_file_method(name, replacement)
    original = File.method(name)
    redefine_file_method(name, &replacement)
    yield
  ensure
    redefine_file_method(name, &original)
  end

  def redefine_file_method(name, &body)
    verbose, $VERBOSE = $VERBOSE, nil
    File.singleton_class.send(:define_method, name, &body)
  ensure
    $VERBOSE = verbose
  end

  def test_writes_to_stdout_without_a_path
    @writer.write("# Hi\n")

    assert_equal "# Hi\n", @stdout.string
  end

  def test_writes_new_file_with_exact_bytes
    @writer.write("café\n", path: path)

    assert_equal "café\n".b, File.binread(path)
    assert_empty leftovers
  end

  def test_uses_ordinary_file_permissions
    @writer.write("x\n", path: path)

    assert_equal 0o666 & ~File.umask, File.stat(path).mode & 0o777
  end

  def test_supports_paths_with_spaces
    spaced = path("my saved page.md")
    @writer.write("x\n", path: spaced)

    assert_equal "x\n", File.read(spaced)
  end

  def test_refuses_existing_file_without_force
    File.write(path, "original")

    error = assert_raises(Sentei::OutputError) { @writer.write("new", path: path) }

    assert_match(/use --force/, error.message)
    assert_equal "original", File.read(path)
    assert_empty leftovers
  end

  def test_refuses_dangling_symlink_without_force
    File.symlink(path("missing-target"), path)

    assert_raises(Sentei::OutputError) { @writer.write("new", path: path) }
    refute File.exist?(path("missing-target"))
    assert_empty leftovers
  end

  def test_force_replaces_existing_file
    File.write(path, "original")

    @writer.write("new", path: path, force: true)

    assert_equal "new", File.read(path)
    assert_empty leftovers
  end

  def test_check_refuses_existing_file_early_unless_forced
    File.write(path, "original")

    assert_raises(Sentei::OutputError) { @writer.check(path) }
    @writer.check(path, force: true)
    @writer.check(nil)
  end

  def test_check_refuses_dangling_symlink_early_unless_forced
    File.symlink(path("missing-target"), path)

    assert_raises(Sentei::OutputError) { @writer.check(path) }
    @writer.check(path, force: true)
  end

  def test_rejects_directory_even_with_force
    assert_raises(Sentei::OutputError) { @writer.write("x", path: @dir, force: true) }
    assert_raises(Sentei::OutputError) { @writer.check(@dir, force: true) }
  end

  def test_reports_missing_directory
    error = assert_raises(Sentei::OutputError) { @writer.write("x", path: path("nope/page.md")) }

    assert_match(/directory does not exist/, error.message)
  end

  # The destination appears after the up-front check: the atomic link must
  # still refuse to replace it.
  def test_race_creating_destination_is_not_clobbered
    @writer.check(path)
    File.write(path, "winner")

    assert_raises(Sentei::OutputError) { @writer.write("loser", path: path) }
    assert_equal "winner", File.read(path)
    assert_empty leftovers
  end

  def test_cleans_up_when_publishing_fails
    with_file_method(:link, ->(*) { raise Errno::EIO }) do
      assert_raises(Sentei::OutputError) { @writer.write("x", path: path) }
    end

    refute File.exist?(path)
    assert_empty leftovers
  end

  def test_cleans_up_when_forced_rename_fails
    File.write(path, "original")

    with_file_method(:rename, ->(*) { raise Errno::EIO }) do
      assert_raises(Sentei::OutputError) { @writer.write("x", path: path, force: true) }
    end

    assert_equal "original", File.read(path)
    assert_empty leftovers
  end

  def test_refuses_filesystem_without_hard_links
    with_file_method(:link, ->(*) { raise Errno::EPERM }) do
      error = assert_raises(Sentei::OutputError) { @writer.write("x", path: path) }
      assert_match(/hard links/, error.message)
    end

    refute File.exist?(path)
    assert_empty leftovers
  end

  def test_stdout_failure_is_an_output_error
    broken = Object.new
    def broken.write(*) = raise(Errno::EPIPE)

    assert_raises(Sentei::OutputError) { Sentei::OutputWriter.new(stdout: broken).write("x") }
  end

  def test_closed_stdout_is_an_output_error
    closed = StringIO.new
    closed.close

    assert_raises(Sentei::OutputError) { Sentei::OutputWriter.new(stdout: closed).write("x") }
  end
end
