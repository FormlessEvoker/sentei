# frozen_string_literal: true

module Sentei
  # Reads raw HTML bytes from a named file or standard input ("-").
  # The source is only ever opened for reading, and never more than
  # MAX_BYTES + 1 bytes are read from it.
  class InputReader
    STDIN_SOURCE = "-"

    # Saved pages are typically well under 1 MiB; 10 MiB leaves ample headroom
    # for inlined assets while bounding memory use on hostile input.
    MAX_BYTES = 10 * 1024 * 1024

    def initialize(stdin:, max_bytes: MAX_BYTES)
      @stdin = stdin
      @max_bytes = max_bytes
    end

    def read(source)
      data = source == STDIN_SOURCE ? read_stdin : read_file(source)
      raise InputError, "input exceeds the maximum size of #{describe_limit}" if data.bytesize > @max_bytes
      raise InputError, "input is empty" if data.strip.empty?

      data
    end

    private

    def read_stdin
      @stdin.binmode
      read_bounded(@stdin)
    end

    def read_file(path)
      raise InputError, "input is a directory: #{path}" if File.directory?(path)

      File.open(path, "rb") { |file| read_bounded(file) }
    rescue Errno::ENOENT
      raise InputError, "input file not found: #{path}"
    rescue Errno::EACCES
      raise InputError, "input file is not readable: #{path}"
    rescue SystemCallError
      raise InputError, "input file could not be read: #{path}"
    end

    # One byte past the limit is enough to detect oversize input.
    def read_bounded(io)
      io.read(@max_bytes + 1).to_s
    end

    def describe_limit
      (@max_bytes % (1024 * 1024)).zero? ? "#{@max_bytes / (1024 * 1024)} MiB" : "#{@max_bytes} bytes"
    end
  end
end
