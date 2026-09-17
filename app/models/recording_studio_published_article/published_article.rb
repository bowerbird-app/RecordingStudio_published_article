# frozen_string_literal: true

module RecordingStudioPublishedArticle
  class PublishedArticle < ApplicationRecord
    include RecordingStudio::Recordable

    self.table_name = "recording_studio_published_article_articles"

    include RecordingStudio::Capabilities::Attachable.to(
      allowed_content_types: ["image/*", "application/pdf"],
      enabled_attachment_kinds: %i[image file]
    )

    class << self
      def declare!
        recording_studio_recordable label: "Article",
                                    plural_label: "Articles",
                                    root: false,
                                    allowed_parent_types: RecordingStudioPublishedArticle.article_parent_types
      end
    end

    declare!

    validates :title, presence: true
    validate :url_must_be_http_url
    validate :publication_recording_must_be_a_publication

    before_create { self.created_at ||= Time.current }

    def publication_name
      publication_recording&.recordable&.try(:name)
    end

    def publication_recording
      RecordingStudioPublishedArticle.publication_recording_for(
        RecordingStudio::Recording.find_by(id: publication_recording_id, trashed_at: nil)
      )
    end

    private

    def url_must_be_http_url
      return if url.blank?

      uri = URI.parse(url)
      return if uri.is_a?(URI::HTTP) && uri.host.present?

      errors.add(:url, "must be an http or https URL")
    rescue URI::InvalidURIError
      errors.add(:url, "must be an http or https URL")
    end

    def publication_recording_must_be_a_publication
      return if publication_recording_id.blank?

      recording = RecordingStudio::Recording.find_by(id: publication_recording_id, trashed_at: nil)
      return if recording&.recordable_type == RecordingStudioPublishedArticle::PUBLICATION_TYPE

      errors.add(:publication_recording_id, "must point at a live publication")
    end
  end
end
