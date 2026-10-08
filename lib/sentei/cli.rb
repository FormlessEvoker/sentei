# frozen_string_literal: true

require "optparse"

module Sentei
  # Command-line adapter: parses arguments and maps failures to exit statuses.
  module CLI
    EXIT_SUCCESS = 0
    EXIT_INVALID_INPUT = 1
    EXIT_NO_CONTENT = 2
    EXIT_DEPENDENCY_FAILURE = 3
    EXIT_OUTPUT_FAILURE = 4

    USAGE = <<~TEXT
      Usage: sentei [options] INPUT
             sentei [options] -

      Convert a local HTML file (or "-" for standard input) to GitHub-Flavored
      Markdown on standard output, or to a file with --output. Input larger than
      10 MiB is rejected. Sentei never fetches URLs or remote assets.
    TEXT

    def self.run(argv, stdin:, stdout:, stderr:, pandoc: Pandoc.new)
      options = {}
      parser = option_parser(options)
      arguments = parser.parse(argv)

      return show(stdout, parser.help) if options[:help]
      return show(stdout, "sentei #{VERSION}") if options[:version]

      return usage_error(stderr, "expected exactly one INPUT (use - for standard input)") unless arguments.length == 1

      return usage_error(stderr, "--output requires a non-empty path") if options[:output]&.empty?
      return usage_error(stderr, "--force requires --output") if options[:force] && !options[:output]

      Application.new(stdin: stdin, stdout: stdout, pandoc: pandoc)
                 .run(arguments.first, output: options[:output], force: options.fetch(:force, false))
      EXIT_SUCCESS
    rescue OptionParser::ParseError => e
      usage_error(stderr, e.message)
    rescue InputError, SelectorError => e
      failure(stderr, e, EXIT_INVALID_INPUT)
    rescue EmptyOutputError => e
      failure(stderr, e, EXIT_NO_CONTENT)
    rescue DependencyError, ConversionError => e
      failure(stderr, e, EXIT_DEPENDENCY_FAILURE)
    rescue OutputError => e
      failure(stderr, e, EXIT_OUTPUT_FAILURE)
    end

    def self.option_parser(options)
      OptionParser.new do |opts|
        opts.banner = USAGE
        opts.separator ""
        opts.separator "Options:"
        opts.on("-o", "--output PATH", "Write Markdown to PATH") { |path| options[:output] = path }
        opts.on("--force", "Allow replacement of an existing output file") { options[:force] = true }
        opts.on("-h", "--help", "Show help") { options[:help] = true }
        opts.on("-v", "--version", "Show version") { options[:version] = true }
      end
    end
    private_class_method :option_parser

    def self.failure(stderr, error, status)
      stderr.puts "sentei: #{error.message}"
      status
    end
    private_class_method :failure

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
