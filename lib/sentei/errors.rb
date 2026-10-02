# frozen_string_literal: true

module Sentei
  # Base class for failures Sentei reports to the user. Messages must never
  # include document content.
  class Error < StandardError; end

  # Missing, unreadable, or empty input.
  class InputError < Error; end

  # An invalid CSS selector, or one that matches other than exactly one element.
  class SelectorError < Error; end

  # Extraction produced no usable content.
  class ExtractionError < Error; end

  # A required runtime dependency (Nokogiri or Pandoc) is unavailable.
  class DependencyError < Error; end

  # Pandoc ran but could not convert the document.
  class ConversionError < Error; end

  # The output could not be written safely.
  class OutputError < Error; end
end
