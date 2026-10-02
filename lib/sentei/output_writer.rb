# frozen_string_literal: true

require "securerandom"

module Sentei
  # Writes Markdown to standard output or, atomically, to a named file.
  #
  # File output goes to a temporary file in the destination directory and is
  # then moved into place, so readers see either the old file or the complete
  # new one, never a partial write. Without force the move is a hard link,
  # which fails if the destination exists, closing the race between checking
  # for and creating the file.
  class OutputWriter
    def initialize(stdout:)
      @stdout = stdout
    end

    # Fails early, before any conversion work, when the destination is
    # already known to be unusable. write still enforces this atomically.
    def check(path, force: false)
      return unless path

      raise OutputError, "output path is a directory: #{path}" if File.directory?(path)
      raise OutputError, "output file exists (use --force to replace it): #{path}" if File.exist?(path) && !force
    end

    def write(markdown, path: nil, force: false)
      return write_stdout(markdown) unless path

      write_file(markdown, path, force)
    end

    private

    def write_stdout(markdown)
      @stdout.write(markdown)
    rescue SystemCallError
      raise OutputError, "could not write to standard output"
    end

    def write_file(markdown, path, force)
      raise OutputError, "output path is a directory: #{path}" if File.directory?(path)

      temp = temp_path(path)
      begin
        write_temp(temp, markdown)
        publish(temp, path, force)
      ensure
        File.unlink(temp) if File.exist?(temp) || File.symlink?(temp)
      end
    rescue Errno::ENOENT
      raise OutputError, "output directory does not exist: #{File.dirname(path)}"
    rescue Errno::EACCES, Errno::EPERM, Errno::EROFS
      raise OutputError, "output location is not writable: #{path}"
    rescue SystemCallError
      raise OutputError, "output could not be written: #{path}"
    end

    # A fixed-length name keeps long destination names within filesystem limits.
    def temp_path(path)
      File.join(File.dirname(path), ".sentei-#{Process.pid}-#{SecureRandom.hex(6)}.tmp")
    end

    # O_EXCL guarantees the temporary file is ours; 0666 lets the umask pick
    # the permissions an ordinary redirect would have produced.
    def write_temp(temp, markdown)
      flags = File::WRONLY | File::CREAT | File::EXCL
      File.open(temp, flags, 0o666) do |file|
        file.binmode
        file.write(markdown)
        file.fsync
      end
    end

    def publish(temp, path, force)
      return File.rename(temp, path) if force

      link_without_replacing(temp, path)
    end

    def link_without_replacing(temp, path)
      File.link(temp, path)
    rescue Errno::EEXIST
      raise OutputError, "output file exists (use --force to replace it): #{path}"
    rescue Errno::EPERM, Errno::ENOTSUP, Errno::EOPNOTSUPP, NotImplementedError
      claim_then_rename(temp, path)
    end

    # Filesystems without hard links: claim the name exclusively, then move
    # the finished file over the claim.
    def claim_then_rename(temp, path)
      begin
        File.open(path, File::WRONLY | File::CREAT | File::EXCL, 0o666).close
      rescue Errno::EEXIST
        raise OutputError, "output file exists (use --force to replace it): #{path}"
      end

      begin
        File.rename(temp, path)
      rescue SystemCallError
        File.unlink(path)
        raise
      end
    end
  end
end
