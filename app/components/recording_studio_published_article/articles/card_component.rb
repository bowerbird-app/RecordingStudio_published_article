# frozen_string_literal: true

module RecordingStudioPublishedArticle
  module Articles
    class CardComponent < ViewComponent::Base
      include RecordingStudioPublishedArticle::ArticlePresentation

      def initialize(article_recording:, show_path:, badges_only: false)
        super()
        @article_recording = article_recording
        @show_path = show_path
        @badges_only = badges_only
      end

      def badges_only?
        @badges_only
      end
    end
  end
end
