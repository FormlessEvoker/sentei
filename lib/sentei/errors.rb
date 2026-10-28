# frozen_string_literal: true

module Sentei
  # Base class for failures Sentei reports to the user. Messages must never
  # include document content.
  class Error < StandardError; end

  # Missing, unreadable, empty, or oversized input.
  class InputError < Error; end

  # An invalid CSS selector.
  class SelectorError < Error; end

  # Nothing remained to convert after pruning.
  class EmptyOutputError < Error; end

  # A required runtime dependency (Nokogiri or Pandoc) is unavailable.
  class DependencyError < Error; end

  # Pandoc ran but could not convert the document.
  class ConversionError < Error; end

  # The output could not be written safely.
  class OutputError < Error; end
end
