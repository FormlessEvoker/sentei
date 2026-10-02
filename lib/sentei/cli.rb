# frozen_string_literal: true

require "optparse"

module Sentei
  # Command-line adapter: parses arguments and maps failures to exit statuses.
  module CLI
    EXIT_SUCCESS = 0
    EXIT_INVALID_INPUT = 1
    EXIT_DEPENDENCY_FAILURE = 3

    USAGE = <<~TEXT
      Usage: sentei [options] INPUT
             sentei [options] -

      Convert a local HTML file (or "-" for standard input) to GitHub-Flavored
      Markdown on standard output. Sentei never fetches URLs or remote assets.
    TEXT

    def self.run(argv, stdin:, stdout:, stderr:, pandoc: Pandoc.new)
      options = {}
      parser = option_parser(options)
      arguments = parser.parse(argv)

      return show(stdout, parser.help) if options[:help]
      return show(stdout, "sentei #{VERSION}") if options[:version]

      return usage_error(stderr, "expected exactly one INPUT (use - for standard input)") unless arguments.length == 1

      Application.new(stdin: stdin, stdout: stdout, pandoc: pandoc).run(arguments.first)
      EXIT_SUCCESS
    rescue OptionParser::ParseError => e
      usage_error(stderr, e.message)
    rescue InputError => e
      stderr.puts "sentei: #{e.message}"
      EXIT_INVALID_INPUT
    rescue DependencyError, ConversionError => e
      stderr.puts "sentei: #{e.message}"
      EXIT_DEPENDENCY_FAILURE
    end

    def self.option_parser(options)
      OptionParser.new do |opts|
        opts.banner = USAGE
        opts.separator ""
        opts.separator "Options:"
        opts.on("-h", "--help", "Show help") { options[:help] = true }
        opts.on("-v", "--version", "Show version") { options[:version] = true }
      end
    end
    private_class_method :option_parser

    def self.usage_error(stderr, message)
      stderr.puts "sentei: #{message}"
      stderr.puts "Try 'sentei --help' for more information."
      EXIT_INVALID_INPUT
    end
    private_class_method :usage_error

    def self.show(stdout, text)
      stdout.puts text
      EXIT_SUCCESS
    end
    private_class_method :show
  end
end
