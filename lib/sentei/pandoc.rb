# frozen_string_literal: true

require "open3"

module Sentei
  # Converts HTML to GitHub-Flavored Markdown with the installed Pandoc.
  class Pandoc
    FENCED_CODE_FILTER = File.expand_path("pandoc/fenced_code.lua", __dir__)

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
      markdown, _stderr, status = Open3.capture3(@executable, *ARGUMENTS, stdin_data: html, binmode: true)
      # Pandoc's stderr can quote document content, so report only the status.
      raise ConversionError, "pandoc #{describe_failure(status)}" unless status.success?

      markdown.force_encoding(Encoding::UTF_8)
    rescue Errno::ENOENT
      raise DependencyError, "pandoc executable not found; install Pandoc (for example, `brew install pandoc`)"
    rescue Errno::EACCES
      raise DependencyError, "pandoc executable is not runnable: #{@executable}"
    end

    private

    def describe_failure(status)
      if status.signaled?
        "was terminated by signal #{status.termsig}"
      else
        "failed with exit status #{status.exitstatus}"
      end
    end
  end
end
