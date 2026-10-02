# frozen_string_literal: true

module Sentei
  # Runs the conversion pipeline: read, parse, convert, write.
  class Application
    def initialize(stdin:, stdout:, pandoc: Pandoc.new)
      @reader = InputReader.new(stdin: stdin)
      @stdout = stdout
      @pandoc = pandoc
    end

    def run(source)
      Document.load_parser
      html = @reader.read(source)
      markdown = @pandoc.convert(Document.new(html).body_html)
      @stdout.write(markdown)
    end
  end
end
