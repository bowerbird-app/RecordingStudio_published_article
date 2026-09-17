# frozen_string_literal: true

RecordingStudioPublishedArticle.configure do |config|
  config.article_parent_types = %w[Workspace Folder RecordingStudioPublications::Publication]
end
