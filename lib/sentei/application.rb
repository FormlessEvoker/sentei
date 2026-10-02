# frozen_string_literal: true

module Sentei
  # Runs the conversion pipeline: read, parse, convert, write.
  class Application
    def initialize(stdin:, stdout:, pandoc: Pandoc.new)
      @reader = InputReader.new(stdin: stdin)
      @writer = OutputWriter.new(stdout: stdout)
      @pandoc = pandoc
    end

    def run(source, output: nil, force: false)
      Document.load_parser
      check_output(source, output, force)
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
      return if source == InputReader::STDIN_SOURCE
      return unless File.exist?(output) && File.exist?(source) && File.identical?(source, output)

      raise OutputError, "output path is the input file: #{output}"
    end
  end
end
