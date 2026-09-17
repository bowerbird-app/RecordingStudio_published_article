# frozen_string_literal: true

class CreateRecordingStudioPublishedArticleArticles < ActiveRecord::Migration[8.1]
  def change
    create_table :recording_studio_published_article_articles, id: :uuid do |t|
      t.string :title, null: false
      t.string :url
      t.datetime :published_at
      t.string :author
      t.text :excerpt
      t.uuid :publication_recording_id
      t.datetime :created_at, null: false
    end

    add_index :recording_studio_published_article_articles, :publication_recording_id
    add_index :recording_studio_published_article_articles, :author
    add_index :recording_studio_published_article_articles, :published_at
    add_index :recording_studio_published_article_articles, :title
  end
end
