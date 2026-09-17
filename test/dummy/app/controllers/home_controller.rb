class HomeController < ApplicationController
  def index
    @workspace_recording = studio_workspace_recording
    @folder_recording = product_docs_folder_recording
    @publication_recording = atlantic_publication_recording
    @workspace_articles = article_collection_for(@workspace_recording)
    @folder_articles = article_collection_for(@folder_recording)
    @publication_articles = article_collection_for(@publication_recording)
  end

  private

  def article_collection_for(parent_recording)
    RecordingStudioPublishedArticle::Queries::Collection.call(parent_recording: parent_recording)
  end

  def studio_workspace_recording
    workspace = Workspace.find_by(name: "Studio Workspace")
    return if workspace.blank?

    RecordingStudio.root_recording_for(workspace)
  end

  def product_docs_folder_recording
    folder = Folder.find_by(name: "Product Docs")
    return if folder.blank?

    RecordingStudio::Recording.find_by(recordable: folder, trashed_at: nil)
  end

  def atlantic_publication_recording
    publication = RecordingStudioPublications::Publication.find_by(key: "the-atlantic")
    RecordingStudioPublishedArticle.publication_recording_for(publication)
  end
end
