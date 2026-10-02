# frozen_string_literal: true

require "open3"

module Sentei
  # Converts HTML to GitHub-Flavored Markdown with the installed Pandoc.
  class Pandoc
    FENCED_CODE_FILTER = File.expand_path("pandoc/fenced_code.lua", __dir__)

    MINIMUM_VERSION = Gem::Version.new("2.15")

    ARGUMENTS = [
      "--sandbox",
      "--from=html",
      "--to=gfm",
      "--markdown-headings=atx",
      "--wrap=none",
      "--lua-filter=#{FENCED_CODE_FILTER}"
    ].freeze

    def initialize(executable: "pandoc")
      @executable = executable
    end

    def convert(html)
      check_version
      # Pandoc's stderr can quote document content, so discard it and report
      # only the status.
      markdown, status = Open3.capture2(@executable, *ARGUMENTS, stdin_data: html, binmode: true, err: File::NULL)
      raise ConversionError, "pandoc #{describe_failure(status)}" unless status.success?

      markdown.force_encoding(Encoding::UTF_8)
    rescue Errno::ENOENT
      raise DependencyError, "pandoc executable not found; install Pandoc (for example, `brew install pandoc`)"
    rescue Errno::EACCES
      raise DependencyError, "pandoc executable is not runnable: #{@executable}"
    end

    private

    # Older Pandoc releases reject options such as --sandbox with a diagnostic
    # that is discarded, so check the version first to give an actionable error.
    def check_version
      return if @version_checked

      output, status = Open3.capture2(@executable, "--version", err: File::NULL)
      version = output[/\Apandoc(?:\.exe)?\s+(\d+(?:\.\d+)*)/, 1] if status.success?
      raise DependencyError, "could not determine the Pandoc version; Pandoc #{MINIMUM_VERSION} or newer is required" unless version

      if Gem::Version.new(version) < MINIMUM_VERSION
        raise DependencyError, "Pandoc #{version} is too old; Pandoc #{MINIMUM_VERSION} or newer is required"
      end

      @version_checked = true
    end

    def describe_failure(status)
      if status.signaled?
        "was terminated by signal #{status.termsig}"
      else
        "failed with exit status #{status.exitstatus}"
      end
    end
  end
end
