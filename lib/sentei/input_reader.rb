# frozen_string_literal: true

module Sentei
  # Reads raw HTML bytes from a named file or standard input ("-").
  # The source is only ever opened for reading.
  class InputReader
    STDIN_SOURCE = "-"

    def initialize(stdin:)
      @stdin = stdin
    end

    def read(source)
      data = source == STDIN_SOURCE ? read_stdin : read_file(source)
      raise InputError, "input is empty" if data.strip.empty?

      data
    end

    private

    def read_stdin
      @stdin.binmode
      @stdin.read.to_s
    end

    def read_file(path)
      raise InputError, "input is a directory: #{path}" if File.directory?(path)

      File.binread(path)
    rescue Errno::ENOENT
      raise InputError, "input file not found: #{path}"
    rescue Errno::EACCES
      raise InputError, "input file is not readable: #{path}"
    end
  end
end
