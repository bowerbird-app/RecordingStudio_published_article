# frozen_string_literal: true

require "recording_studio"
require "recording_studio_publications"
require "recording_studio_attachable"
require "recording_studio_published_article/version"
require "recording_studio_published_article/engine"
require "recording_studio_published_article/configuration"
require "recording_studio_published_article/queries/collection"

unless defined?(RecordingStudio::Capabilities::Example)
  require "recording_studio_published_article/capabilities/example"
end

module RecordingStudioPublishedArticle
  PDF_CONTENT_TYPE = "application/pdf"
  PUBLICATION_TYPE = "RecordingStudioPublications::Publication"
  ATTACHMENT_LIST_PER_PAGE = 100

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
      redeclare_published_article!
      configuration
    end

    def article_parent_types
      Array(configuration.article_parent_types).map(&:to_s)
    end

    def article_parent_types=(types)
      configuration.article_parent_types = Array(types).map(&:to_s)
      redeclare_published_article!
      article_parent_types
    end

    def publication_recording_for(publication_or_recording)
      return if publication_or_recording.blank?

      if publication_or_recording.respond_to?(:recordable_type)
        return publication_or_recording if publication_or_recording.recordable_type == PUBLICATION_TYPE

        return
      end

      publication_class = PUBLICATION_TYPE.safe_constantize
      return unless publication_class && publication_or_recording.is_a?(publication_class)

      RecordingStudioPublications.recording_for(publication_or_recording)
    end

    def pdf_attachments(article_recording)
      return [] unless article_recording.respond_to?(:files)

      article_recording.files(per_page: ATTACHMENT_LIST_PER_PAGE).select do |recording|
        recording.recordable&.content_type == PDF_CONTENT_TYPE
      end
    end

    def screenshot_attachments(article_recording)
      return [] unless article_recording.respond_to?(:images)

      article_recording.images(per_page: ATTACHMENT_LIST_PER_PAGE).to_a
    end

    def redeclare_published_article!
      return unless const_defined?(:PublishedArticle, false)

      PublishedArticle.declare!
    end
  end
end
