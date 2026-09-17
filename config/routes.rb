# frozen_string_literal: true

RecordingStudioPublishedArticle::Engine.routes.draw do
  get "recordings/:recording_id/articles", to: "articles#index", as: :recording_articles
  get "articles/:id", to: "articles#show", as: :article
  root "home#index"
end
