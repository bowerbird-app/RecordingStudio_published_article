# frozen_string_literal: true

module RecordingStudioPublishedArticle
  module Queries
    class Collection # rubocop:disable Metrics/ClassLength
      ARTICLE_TYPE = "RecordingStudioPublishedArticle::PublishedArticle"
      SORTS = %i[published_at_desc published_at_asc title].freeze
      SORT_SQL = {
        published_at_asc: "%<table>s.%<published>s ASC NULLS LAST, %<table>s.%<id>s ASC",
        title: "%<table>s.%<title>s ASC, %<table>s.%<id>s ASC",
        published_at_desc: "%<table>s.%<published>s DESC NULLS LAST, %<table>s.%<id>s DESC"
      }.freeze

      def self.call(...)
        new(...).call
      end

      def initialize(parent_recording:, filters: {}, extra_scope: nil, sort: :published_at_desc)
        @parent_recording = parent_recording
        @filters = stringify_filters(filters)
        @extra_scope = extra_scope
        @sort = normalize_sort(sort)
      end

      def call
        return RecordingStudio::Recording.none if parent_recording.blank?

        relation = base_relation
        relation = apply_attachment_kind(relation)
        relation = apply_extra_scope(relation)
        relation.includes(:recordable)
      end

      private

      attr_reader :parent_recording, :filters, :extra_scope, :sort

      def stringify_filters(filters)
        (filters.presence || {}).to_h.stringify_keys
      end

      def normalize_sort(value)
        key = value.to_s.to_sym
        SORTS.include?(key) ? key : :published_at_desc
      end

      def base_relation
        parent_recording.recordings_query(
          include_children: true,
          type: ARTICLE_TYPE,
          parent_id: parent_recording.id,
          recordable_filters: equality_filters,
          recordable_scope: method(:apply_recordable_scope),
          allow_unsafe_recordable_query: true
        ).where(trashed_at: nil)
      end

      def equality_filters
        {}.tap do |hash|
          if filters["publication_recording_id"].present?
            hash[:publication_recording_id] = filters["publication_recording_id"]
          end
          hash[:author] = filters["author"] if filters["author"].present?
        end
      end

      def apply_recordable_scope(relation)
        relation = apply_search(relation)
        relation = apply_year(relation)
        relation = apply_published_range(relation)
        relation = apply_has_url(relation)
        apply_sort(relation)
      end

      def apply_search(relation)
        query = filters["q"].to_s.strip
        return relation if query.blank?

        table = article_table
        pattern = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
        matcher = table[:title].matches(pattern, nil, false)
                               .or(table[:author].matches(pattern, nil, false))
                               .or(table[:excerpt].matches(pattern, nil, false))
        relation.where(matcher)
      end

      def apply_year(relation)
        year = filters["year"].presence&.to_i
        return relation if year.blank? || year.zero?

        start_at = Time.utc(year, 1, 1)
        table = article_table
        relation.where(table[:published_at].gteq(start_at).and(table[:published_at].lt(start_at.next_year)))
      end

      def apply_published_range(relation)
        relation = apply_bound(relation, filters["published_from"], :gteq)
        apply_bound(relation, filters["published_to"], :lteq)
      end

      def apply_bound(relation, value, operator)
        timestamp = parse_time(value)
        return relation if timestamp.blank?

        relation.where(article_table[:published_at].public_send(operator, timestamp))
      end

      def apply_has_url(relation)
        return relation unless url_filter?

        relation.where(url_presence_condition)
      end

      def url_filter?
        filters.key?("has_url") && !filters["has_url"].nil? && filters["has_url"] != ""
      end

      def url_presence_condition
        table = article_table
        if truthy?(filters["has_url"])
          table[:url].not_eq(nil).and(table[:url].not_eq(""))
        else
          table[:url].eq(nil).or(table[:url].eq(""))
        end
      end

      def apply_sort(relation)
        relation.reorder(Arel.sql(sort_sql))
      end

      def sort_sql
        format(
          SORT_SQL.fetch(sort, SORT_SQL[:published_at_desc]),
          table: quote_table,
          id: quote_column("id"),
          published: quote_column("published_at"),
          title: quote_column("title")
        )
      end

      def apply_attachment_kind(relation)
        kind = filters["attachment_kind"].presence&.to_sym
        return relation if kind.blank? || kind == :any

        scoped_by_attachment_kind(relation, kind)
      end

      def scoped_by_attachment_kind(relation, kind)
        case kind
        when :image, :file
          attachments_scope(relation, kind: kind)
        when :pdf
          pdf_scope(relation)
        when :none
          relation.where.not(id: attachments_scope(relation, kind: :all).select(:id))
        else
          relation
        end
      end

      def attachments_scope(relation, kind:)
        RecordingStudioAttachable::Queries::WithAttachments.new(
          scope: relation,
          recordable_type: ARTICLE_TYPE,
          kind: kind
        ).call
      end

      def pdf_scope(relation)
        pdf_ids = RecordingStudioAttachable::Attachment.where(
          content_type: RecordingStudioPublishedArticle::PDF_CONTENT_TYPE
        ).select(:id)
        parent_ids = RecordingStudio::Recording.where(
          recordable_type: RecordingStudioAttachable::Attachment.name,
          recordable_id: pdf_ids,
          trashed_at: nil
        ).select(:parent_recording_id)
        relation.where(id: parent_ids)
      end

      def apply_extra_scope(relation)
        return relation unless extra_scope.respond_to?(:call)

        scoped = extra_scope.call(relation)
        scoped.is_a?(ActiveRecord::Relation) ? scoped : relation
      end

      def article_table
        RecordingStudioPublishedArticle::PublishedArticle.arel_table
      end

      def quote_table
        connection.quote_table_name(RecordingStudioPublishedArticle::PublishedArticle.table_name)
      end

      def quote_column(name)
        connection.quote_column_name(name)
      end

      def connection
        RecordingStudioPublishedArticle::PublishedArticle.connection
      end

      def parse_time(value)
        return if value.blank?
        return value.to_time if value.respond_to?(:to_time) && !value.is_a?(String)

        Time.zone.parse(value.to_s)
      rescue ArgumentError
        nil
      end

      def truthy?(value)
        ActiveModel::Type::Boolean.new.cast(value)
      end
    end
  end
end
