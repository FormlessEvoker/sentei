# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "minitest/autorun"
require "stringio"
require "sentei"

Sentei::Document.load_parser

module TestHelpers
  FIXTURES = File.expand_path("fixtures", __dir__)
  SUPPORT = File.expand_path("support", __dir__)

  def fixture_path(name)
    File.join(FIXTURES, name)
  end

  def support_path(name)
    File.join(SUPPORT, name)
  end

  def require_pandoc
    skip "pandoc is not installed" unless system("pandoc", "--version", out: File::NULL, err: File::NULL)
  end
end

Minitest::Test.include(TestHelpers)
