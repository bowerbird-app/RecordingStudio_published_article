# frozen_string_literal: true

module RecordingStudioPublishedArticle
  module ArticlesHelper
    include ArticlePresentation

    def article_filter_query
      params.permit(
        :q,
        :publication_recording_id,
        :author,
        :year,
        :published_from,
        :published_to,
        :has_url,
        :attachment_kind
      ).to_h.symbolize_keys.compact_blank
    end
  end
end
