# frozen_string_literal: true

module Sentei
  # Base class for failures Sentei reports to the user. Messages must never
  # include document content.
  class Error < StandardError; end

  # Missing, unreadable, or empty input.
  class InputError < Error; end

  # A required runtime dependency (Nokogiri or Pandoc) is unavailable.
  class DependencyError < Error; end

  # Pandoc ran but could not convert the document.
  class ConversionError < Error; end
end
