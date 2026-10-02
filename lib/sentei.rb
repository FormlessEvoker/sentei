require "nokogiri"
require "open3"
require "optparse"
require "tempfile"
require "uri"

module Sentei
  MAX_INPUT_SIZE = 10 * 1024 * 1024
  REQUIRED_NOKOGIRI_VERSION = Gem::Version.new("1.19.4")
  MIN_PANDOC_VERSION = Gem::Version.new("2.0.0")
  REMOVED_TAGS = %w[
    head script style template noscript object embed iframe frame frameset form
    button input select textarea option svg canvas audio video source
  ].freeze
  CONTENT_TAGS = %w[
    a abbr address article aside b blockquote body br caption code dd del div dl
    dt em fieldset figcaption figure footer h1 h2 h3 h4 h5 h6 header hr html i img
    li main ol p pre q s section small span strong sub sup table tbody td tfoot
    th thead tr u ul
  ].freeze
  SAFE_SCHEMES = %w[http https mailto tel].freeze

  class Error < StandardError
    attr_reader :status

    def initialize(message, status)
      super(message)
      @status = status
    end
  end

  class Converter
    def initialize(options, verbose: false)
      @options = options
      @verbose = verbose
    end

    def convert(input)
      document = parse(input)
      clean_document(document)
      root = select_root(document)
      clean_root(root)
      raise Error.new("No meaningful document content was found.", 2) unless meaningful?(root)

      html = root.to_html
      [convert_with_pandoc(html), html]
    end

    private

    def parse(input)
      unless input.match?(/<\s*[a-z][^>]*>/i)
        raise Error.new("Input does not contain HTML content.", 1)
      end
      parse_options = Nokogiri::XML::ParseOptions::RECOVER | Nokogiri::XML::ParseOptions::NONET
      document = Nokogiri::HTML::Document.parse(input, nil, nil, parse_options)
      unless document.at_css("body")&.element_children&.any?
        raise Error.new("Input does not contain HTML content.", 1)
      end

      document
    rescue Nokogiri::XML::SyntaxError
      raise Error.new("Input could not be parsed as HTML.", 1)
    end

    def clean_document(document)
      REMOVED_TAGS.each { |tag| document.css(tag).remove }
      @options[:remove].each do |selector|
        document.css(selector).remove
      rescue Nokogiri::CSS::SyntaxError
        raise Error.new("Invalid CSS selector for --remove: #{selector}", 1)
      end
      document.xpath("//comment()").remove
    end

    def clean_root(root)
      unless @options[:no_extract]
        if hidden_or_boilerplate?(root)
          root.children.remove
        else
          root.css("nav, [role='navigation'], [hidden]").remove
          root.xpath(".//*[@aria-hidden and translate(@aria-hidden, 'TRUE', 'true') = 'true']").remove
          root.css("[style]").each do |element|
            element.remove if hidden_style?(element)
          end
        end
      end
      root.xpath(".//comment()").remove
      root.xpath(".//*").reverse_each do |element|
        sanitize_attributes(element)
        next if CONTENT_TAGS.include?(element.name.downcase)

        element.children.to_a.each { |child| element.add_previous_sibling(child) }
        element.remove
      end
      sanitize_attributes(root)
      loop do
        empty = root.xpath(
          ".//*[not(*) and normalize-space(.) = '' and not(self::br or self::hr or self::img or self::pre or self::code)]"
        )
        break if empty.empty?

        empty.remove
      end
    end

    def hidden_or_boilerplate?(element)
      element.matches?("nav, [role='navigation'], [hidden]") ||
        element["aria-hidden"].to_s.casecmp("true").zero? || hidden_style?(element)
    end

    def hidden_style?(element)
      element["style"].to_s.match?(/(?:display\s*:\s*none|visibility\s*:\s*hidden)/i)
    end

    def sanitize_attributes(element)
      allowed = %w[href src alt title]
      allowed << "class" if %w[code pre].include?(element.name)
      allowed << "start" if element.name == "ol"
      allowed.concat(%w[colspan rowspan]) if %w[td th].include?(element.name)
      element.attribute_nodes.each do |attribute|
        element.remove_attribute(attribute.name) unless allowed.include?(attribute.name)
      end
      %w[href src].each do |name|
        value = element[name]
        next unless value

        normalized = normalize_link(value, name)
        normalized ? element[name] = normalized : element.remove_attribute(name)
      end
      return unless element["class"]

      language_classes = element["class"].split.select { |name| name.match?(/\Alanguage-[\w+-]+\z/) }
      element["class"] = language_classes.join(" ")
      element.remove_attribute("class") if language_classes.empty?
    end

    def normalize_link(value, attribute)
      uri = URI.parse(value)
      if uri.scheme
        allowed_schemes = attribute == "href" ? SAFE_SCHEMES : %w[http https]
        return value if allowed_schemes.include?(uri.scheme.downcase)

        return nil
      end
      return value unless @options[:base_url]

      URI.join(@options[:base_url], URI::DEFAULT_PARSER.escape(value)).to_s
    rescue URI::InvalidURIError
      nil
    end

    def select_root(document)
      body = document.at_css("body")
      return body if @options[:no_extract]

      if @options[:selector]
        matches = document.css(@options[:selector])
        raise Error.new("--selector must match exactly one element.", 1) unless matches.length == 1

        return matches.first
      end

      candidates = document.css("main, [role='main'], article")
      if candidates.any?
        root = candidates.max_by { |candidate| meaningful_text(candidate).length }
        verbose("Selected the strongest content root (#{candidates.length} candidate(s)).")
        return root
      end

      body
    rescue Nokogiri::CSS::SyntaxError
      raise Error.new("Invalid CSS selector for --selector.", 1)
    end

    def meaningful?(root)
      !meaningful_text(root).empty? || root.css("img[alt]").any? { |image| !image["alt"].strip.empty? }
    end

    def meaningful_text(root)
      root.text.gsub(/\s+/, " ").strip
    end

    def convert_with_pandoc(html)
      version_output, _version_error, version_status = Open3.capture3("pandoc", "--version")
      version_line = version_output.lines.first.to_s
      version = version_line[/\Apandoc\s+(\d+(?:\.\d+)+)/, 1]
      unless version_status.success? && version
        raise Error.new("Pandoc is unavailable. Install Pandoc 2.0 or newer.", 3)
      end
      if Gem::Version.new(version) < MIN_PANDOC_VERSION
        raise Error.new("Pandoc 2.0 or newer is required (found #{version}).", 3)
      end

      output, _error, status = Open3.capture3(
        "pandoc", "--from=html", "--to=gfm", "--wrap=none", stdin_data: html
      )
      raise Error.new("Pandoc conversion failed.", 3) unless status.success?

      output = output.gsub(/\r\n?/, "\n")
      output.end_with?("\n") ? output : "#{output}\n"
    rescue Errno::ENOENT
      raise Error.new("Pandoc is unavailable. Install Pandoc 2.0 or newer.", 3)
    end

    def verbose(message)
      $stderr.puts(message) if @verbose
    end
  end

  class CLI
    def initialize(input: $stdin, output: $stdout, error: $stderr)
      @stdin = input
      @stdout = output
      @stderr = error
    end

    def run(arguments = ARGV)
      options = { remove: [], force: false, no_extract: false, verbose: false, keep_intermediate: false }
      parser = option_parser(options)
      parser.parse!(arguments)
      if options[:help]
        @stdout.puts(parser)
        return 0
      end
      if options[:version]
        @stdout.puts("sentei #{version}")
        return 0
      end
      check_nokogiri_version
      raise Error.new("Expected exactly one INPUT path or '-'.", 1) unless arguments.length == 1

      input_path = arguments.first
      ensure_distinct_paths(input_path, options[:output]) if options[:output]
      input = read_input(input_path)
      options[:base_url] = normalize_base_url(options[:base_url]) if options[:base_url]
      markdown, html = Converter.new(options, verbose: options[:verbose]).convert(input)
      write_intermediate(html, options) if options[:keep_intermediate]
      if options[:output]
        write_output(options[:output], markdown, options[:force])
      else
        @stdout.write(markdown)
      end
      0
    rescue Error => error
      @stderr.puts(error.message)
      error.status
    rescue OptionParser::ParseError => error
      @stderr.puts(error.message)
      1
    end

    private

    def option_parser(options)
      OptionParser.new do |parser|
        parser.banner = "Usage: sentei [options] INPUT\n       sentei [options] -"
        parser.on("-o", "--output PATH", "Write Markdown to PATH") { |value| options[:output] = value }
        parser.on("--force", "Allow replacement of an existing output file") { options[:force] = true }
        parser.on("--selector CSS", "Use matching element as content root") { |value| options[:selector] = value }
        parser.on("--remove CSS", "Remove matching elements (repeatable)") { |value| options[:remove] << value }
        parser.on("--base-url URL", "Resolve relative links without fetching them") { |value| options[:base_url] = value }
        parser.on("--no-extract", "Clean and convert the complete body") { options[:no_extract] = true }
        parser.on("--keep-intermediate", "Retain cleaned HTML for troubleshooting") { options[:keep_intermediate] = true }
        parser.on("--verbose", "Report processing decisions, never document content") { options[:verbose] = true }
        parser.on("-h", "--help", "Show help") { options[:help] = true }
        parser.on("-v", "--version", "Show version") { options[:version] = true }
      end
    end

    def read_input(path)
      input = if path == "-"
        @stdin.read(MAX_INPUT_SIZE + 1)
      else
        begin
          File.open(path, "rb") { |file| file.read(MAX_INPUT_SIZE + 1) }
        rescue Errno::ENOENT, Errno::EACCES, Errno::EISDIR => error
          raise Error.new("Cannot read input file: #{error.message}", 1)
        end
      end
      input ||= ""
      raise Error.new("Input exceeds the 10 MiB size limit.", 1) if input.bytesize > MAX_INPUT_SIZE
      raise Error.new("Input is empty.", 1) if input.empty?

      input
    end

    def normalize_base_url(value)
      uri = URI.parse(value)
      unless %w[http https].include?(uri.scheme) && uri.host
        raise Error.new("--base-url must be an absolute HTTP or HTTPS URL.", 1)
      end

      uri.to_s
    rescue URI::InvalidURIError
      raise Error.new("--base-url must be an absolute HTTP or HTTPS URL.", 1)
    end

    def ensure_distinct_paths(input_path, output_path)
      return if input_path == "-"

      source = File.realpath(input_path)
      destination = File.expand_path(output_path)
      destination = File.realpath(destination) if File.exist?(destination)
      raise Error.new("Output path must not refer to the input file.", 4) if source == destination
    rescue Errno::ENOENT
      nil
    end

    def write_output(path, contents, force)
      destination = File.expand_path(path)
      directory = File.dirname(destination)
      raise Error.new("Output directory does not exist.", 4) unless File.directory?(directory)
      if (File.exist?(destination) || File.symlink?(destination)) && !force
        raise Error.new("Output already exists; use --force to replace it.", 4)
      end

      Tempfile.create([".sentei-", ".tmp"], directory) do |temporary|
        temporary.binmode
        temporary.write(contents)
        temporary.flush
        temporary.fsync
        force ? File.rename(temporary.path, destination) : File.link(temporary.path, destination)
      end
    rescue SystemCallError => error
      raise Error.new("Could not write output safely: #{error.message}", 4)
    end

    def write_intermediate(html, options)
      path = "#{options[:output] || "sentei"}.cleaned.html"
      write_output(path, html, options[:force])
      @stderr.puts("Intermediate HTML retained at #{File.expand_path(path)}")
    rescue SystemCallError => error
      raise Error.new("Could not retain intermediate HTML: #{error.message}", 4)
    end

    def version
      specification = Gem::Specification.find_by_name("nokogiri")
      "0.1.0 (Nokogiri #{specification.version})"
    rescue Gem::LoadError
      "0.1.0"
    end

    def check_nokogiri_version
      current = Gem::Version.new(Nokogiri::VERSION)
      return if current == REQUIRED_NOKOGIRI_VERSION

      raise Error.new(
        "Nokogiri #{REQUIRED_NOKOGIRI_VERSION} is required; run bundle install (found #{current}).",
        3
      )
    end
  end
end
