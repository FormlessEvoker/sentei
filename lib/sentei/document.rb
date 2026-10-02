# frozen_string_literal: true

module Sentei
  # Parses untrusted HTML with Nokogiri's HTML5 parser, which neither executes
  # scripts nor resolves external resources.
  class Document
    def self.load_parser(require_with: Kernel.method(:require))
      require_with.call("nokogiri")
    rescue LoadError
      raise DependencyError, "Nokogiri is not available; run `bundle install` in the Sentei directory"
    end

    def initialize(html)
      @document = Nokogiri::HTML5.parse(with_detected_encoding(html))
    end

    # The complete <body>, serialized as UTF-8 for Pandoc.
    def body_html
      body = @document.at_css("body")
      raise InputError, "input has no HTML body" unless body

      body.to_html(encoding: "UTF-8")
    end

    private

    # Nokogiri falls back to Windows-1252 for undeclared encodings, which
    # garbles undeclared UTF-8 such as pasted HTML. Prefer UTF-8 whenever the
    # bytes are valid UTF-8; otherwise let Nokogiri sniff a BOM or <meta>.
    def with_detected_encoding(html)
      bytes = html.b
      utf8 = bytes.dup.force_encoding(Encoding::UTF_8)
      utf8.valid_encoding? ? utf8 : bytes
    end
  end
end
