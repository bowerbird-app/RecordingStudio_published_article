# frozen_string_literal: true

module RecordingStudioPublishedArticle
  module ArticlePresentation
    def article_title_for(recording)
      article_recordable(recording)&.try(:title).to_s
    end

    def article_publication_name_for(recording)
      article_recordable(recording)&.try(:publication_name).to_s
    end

    def article_published_on_for(recording)
      published_at = article_recordable(recording)&.published_at
      published_at ? published_at.to_fs(:long) : ""
    end

    def article_url_for(recording)
      article_recordable(recording)&.try(:url).to_s
    end

    def article_recordable(recording)
      recording&.recordable
    end

    def article_has_url?(recording)
      article_url_for(recording).present?
    end

    def article_has_pdf?(recording)
      RecordingStudioPublishedArticle.pdf_attachments(recording).any?
    end

    def article_has_screenshot?(recording)
      RecordingStudioPublishedArticle.screenshot_attachments(recording).any?
    end

    def article_badge_items(recording)
      items = []
      items << { text: "URL", style: :info } if article_has_url?(recording)
      items << { text: "PDF", style: :default } if article_has_pdf?(recording)
      items << { text: "Screenshot", style: :default } if article_has_screenshot?(recording)
      items
    end
  end
end
