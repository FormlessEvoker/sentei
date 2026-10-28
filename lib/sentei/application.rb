# frozen_string_literal: true

module Sentei
  # Runs the conversion pipeline: read, parse, convert, write.
  class Application
    def initialize(stdin:, stdout:, pandoc: Pandoc.new)
      @stdin = stdin
      @reader = InputReader.new(stdin: stdin)
      @writer = OutputWriter.new(stdout: stdout)
      @pandoc = pandoc
    end

    def run(source, output: nil, force: false)
      check_output(source, output, force)
      Document.load_parser
      html = @reader.read(source)
      markdown = @pandoc.convert(Document.new(html).body_html)
      @writer.write(markdown, path: output, force: force)
    end

    private

    # Refuse unusable destinations before doing any work. --force must never
    # let the output replace the input file.
    def check_output(source, output, force)
      return unless output

      @writer.check(output, force: force)
      return unless File.exist?(output) && same_file?(input_for(source), output)

      raise OutputError, "output path is the input file: #{output}"
    end

    # Standard input redirected from a file is that file; a pipe or an
    # in-memory stream is never the output.
    def input_for(source)
      source == InputReader::STDIN_SOURCE ? @stdin : source
    end

    def same_file?(input, output)
      return false unless input.is_a?(String) || input.is_a?(IO)

      File.identical?(input, output)
    end
  end
end
