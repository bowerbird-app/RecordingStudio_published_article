# frozen_string_literal: true

module RecordingStudioPublishedArticle
  class ArticlesController < ApplicationController
    before_action :set_parent_recording, only: :index
    before_action :set_article_recording, only: :show

    def index
      return if performed?

      authorize_view!(@parent_recording)
      return if performed?

      @article_recordings = Queries::Collection.call(
        parent_recording: @parent_recording,
        filters: filter_params,
        sort: sort_param
      )
      @filters = filter_params
      @view = table_view? ? "table" : "cards"
    end

    def show
      return if performed?

      authorize_view!(@article_recording)
    end

    private

    def set_parent_recording
      @parent_recording = RecordingStudio::Recording.find_by(id: params[:recording_id], trashed_at: nil)
      head :not_found if @parent_recording.blank?
    end

    def set_article_recording
      @article_recording = RecordingStudio::Recording.find_by(id: params[:id], trashed_at: nil)
      return if @article_recording&.recordable_type == PublishedArticle.name

      head :not_found
    end

    def table_view?
      params[:view].to_s != "cards"
    end

    def sort_param
      params[:sort].presence&.to_sym || :published_at_desc
    end

    def filter_params
      params.permit(
        :q,
        :publication_recording_id,
        :author,
        :year,
        :published_from,
        :published_to,
        :has_url,
        :attachment_kind
      ).to_h
    end
  end
end
