# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class HomePageTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "signed-in home shows workspace, folder, and publication article indexes" do
    Current.actor = nil
    load Rails.root.join("db/seeds.rb").to_s

    user = User.find_by!(email: "admin@admin.com")
    sign_in user

    get root_path

    assert_response :success
    assert_select "body[data-recording-studio-default-layout='true']", count: 1
    assert_includes response.body, "Published articles"
    assert_includes response.body, "Studio workspace"
    assert_includes response.body, "Product Docs"
    assert_includes response.body, "The Atlantic"
    assert_includes response.body, "The Quiet Crop"
    assert_includes response.body, "Screens from the harvest"
    assert_includes response.body, "Archive copy under The Atlantic"
    assert_includes response.body, recording_studio_published_article.article_path(
      workspace_article_recording
    )
    assert_includes response.body, recording_studio_published_article.article_path(
      folder_article_recording
    )
    refute_includes response.body, "Template Demo"
    refute_includes response.body, "recordable"
  ensure
    Current.actor = nil
  end

  private

  def workspace_article_recording
    workspace = Workspace.find_by!(name: "Studio Workspace")
    root = RecordingStudio.root_recording_for(workspace)
    RecordingStudioPublishedArticle::Queries::Collection.call(parent_recording: root).detect do |recording|
      recording.recordable.title == "The Quiet Crop"
    end
  end

  def folder_article_recording
    folder = Folder.find_by!(name: "Product Docs")
    folder_recording = RecordingStudio::Recording.find_by!(recordable: folder, trashed_at: nil)
    RecordingStudioPublishedArticle::Queries::Collection.call(parent_recording: folder_recording).detect do |recording|
      recording.recordable.title == "Screens from the harvest"
    end
  end
end
