# frozen_string_literal: true

module RecordingStudioPublishedArticle
  module Articles
    class DetailComponent < ViewComponent::Base
      include RecordingStudioPublishedArticle::ArticlePresentation

      def initialize(article_recording:)
        super()
        @article_recording = article_recording
      end

      def article
        @article_recording.recordable
      end

      def attribute_rows
        [
          { label: "Title", value: article_title_for(@article_recording) },
          { label: "Publication", value: article_publication_name_for(@article_recording) },
          { label: "Published", value: article_published_on_for(@article_recording) },
          { label: "Author", value: article&.author },
          { label: "URL", value: article_url_for(@article_recording) },
          { label: "Excerpt", value: article&.excerpt }
        ]
      end

      def screenshots
        RecordingStudioPublishedArticle.screenshot_attachments(@article_recording)
      end

      def pdfs
        RecordingStudioPublishedArticle.pdf_attachments(@article_recording)
      end

      def screenshot_src(recording)
        attachable_routes.attachment_preview_file_path(recording, variant_name: :med)
      end

      def pdf_href(recording)
        attachable_routes.attachment_file_path(recording)
      end

      private

      def attachable_routes
        return helpers.recording_studio_attachable if helpers.respond_to?(:recording_studio_attachable)

        helpers.main_app.recording_studio_attachable
      end
    end
  end
end
