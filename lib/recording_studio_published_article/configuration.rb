# frozen_string_literal: true

module RecordingStudioPublishedArticle
  class Configuration
    attr_accessor :article_parent_types
    attr_reader :hooks

    def initialize
      @article_parent_types = []
      @hooks = RecordingStudio::Hooks.new
    end

    def to_h
      {
        article_parent_types: Array(article_parent_types).map(&:to_s),
        hooks_registered: hooks.instance_variable_get(:@registry).transform_values(&:size)
      }
    end

    def merge!(hash)
      return unless hash.respond_to?(:each)

      hash.each do |key, value|
        setter = "#{key}="
        public_send(setter, value) if respond_to?(setter)
      end
    end
  end
end
