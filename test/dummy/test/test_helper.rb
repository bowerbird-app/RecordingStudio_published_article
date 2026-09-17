# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

require_relative "../../../test/simplecov_helper"
require_relative "../config/environment"
require "rails/test_help"
require_relative "../../../test/support/article_test_helpers"

class ActiveSupport::TestCase
  include ArticleTestHelpers
end

class ActionDispatch::IntegrationTest
  include ArticleTestHelpers
end
