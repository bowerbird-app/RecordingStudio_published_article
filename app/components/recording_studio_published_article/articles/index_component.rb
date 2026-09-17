# frozen_string_literal: true

module RecordingStudioPublishedArticle
  module Articles
    class IndexComponent < ViewComponent::Base
      include RecordingStudioPublishedArticle::ArticlePresentation

      def initialize(article_recordings:, parent_recording:, show_path:, filters: {}, view: "table", # rubocop:disable Metrics/ParameterLists, Metrics/MethodLength
                     cards_path: nil, table_path: nil, filter_path: nil, hidden_filters: [],
                     title: "Articles", subtitle: "Saved copies, with a link when you have one.",
                     title_variant: :h1)
        super()
        @article_recordings = article_recordings
        @parent_recording = parent_recording
        @filters = (filters.presence || {}).stringify_keys
        @show_path = show_path
        @view = view.to_s
        @cards_path = cards_path
        @table_path = table_path
        @filter_path = filter_path
        @hidden_filters = Array(hidden_filters).map(&:to_s)
        @title = title
        @subtitle = subtitle
        @title_variant = title_variant
      end

      def table_view?
        @view != "cards"
      end

      def show_filters?
        @filter_path.present?
      end

      def show_filter?(name)
        show_filters? && @hidden_filters.exclude?(name.to_s)
      end

      def show_view_toggle?
        @cards_path.present? && @table_path.present?
      end

      def publication_options
        options = [["Any publication", ""]]
        return options unless defined?(RecordingStudioPublications)

        RecordingStudioPublications.publications.each do |publication|
          recording = RecordingStudioPublishedArticle.publication_recording_for(publication)
          next if recording.blank?

          options << [publication.name, recording.id]
        end
        options
      end

      def year_options
        current = Time.zone.now.year
        years = ((current - 9)..current).to_a.reverse
        [["Any year", ""]] + years.map { |year| [year.to_s, year.to_s] }
      end

      def url_presence_options
        [
          ["Any URL", ""],
          ["Has a URL", "true"],
          ["No URL", "false"]
        ]
      end

      def attachment_kind_options
        [
          ["Any", ""],
          ["Screenshot", "image"],
          ["PDF", "pdf"],
          ["File", "file"],
          ["None", "none"]
        ]
      end
    end
  end
end
