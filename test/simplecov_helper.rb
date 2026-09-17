# frozen_string_literal: true

return if ENV["DISABLE_SIMPLECOV"] == "true"

begin
  require "simplecov"
rescue LoadError
  return
end

SimpleCov.start do
  enable_coverage :branch
  root File.expand_path("..", __dir__)
  coverage_dir File.expand_path("../coverage", __dir__)
  command_name ENV.fetch("SIMPLECOV_COMMAND_NAME", "gem")
  add_filter "/test/"
  add_filter "/config/"
  add_filter "/db/"
end
