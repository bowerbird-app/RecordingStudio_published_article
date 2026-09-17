# frozen_string_literal: true

require "test_helper"

class RecordingStudioTemplateTest < ActiveSupport::TestCase
  test "dummy app loads root switchable config and controller support" do
    assert_equal [ "all_workspaces" ], RecordingStudioRootSwitchable.configuration.scopes.keys
    assert_equal :application_layout, RecordingStudioRootSwitchable.configuration.layout
    assert_includes ApplicationController.ancestors, RecordingStudio::RootSwitchable::ControllerSupport
    assert_includes ApplicationController.ancestors, RecordingStudio::UsesDefaultLayout
  end

  test "dummy app validates recordable declarations" do
    assert RecordingStudio.validate_recordable_declarations!
    assert_includes RecordingStudio.root_recordable_types, "Workspace"
    assert_includes RecordingStudio.root_recordable_types, "RecordingStudioPublications::PublicationCatalogue"
    assert_equal [ "Workspace", "Folder" ], RecordingStudio.allowed_parent_types_for("Page")
    assert_equal %w[Workspace Folder RecordingStudioPublications::Publication],
                 RecordingStudio.allowed_parent_types_for("RecordingStudioPublishedArticle::PublishedArticle")
  end

  test "dummy app schema keeps accessible grants and excludes removed core tables" do
    connection = ActiveRecord::Base.connection

    assert connection.column_exists?(:recording_studio_recordings, :root_recording_id)
    assert connection.table_exists?(:recording_studio_accesses)
    refute connection.table_exists?(:recording_studio_access_boundaries)
    refute connection.table_exists?(:recording_studio_device_sessions)
  end

  test "dummy seeds use hierarchy idempotently and restore current actor" do
    Current.actor = nil

    load Rails.root.join("db/seeds.rb").to_s

    workspace = Workspace.find_by!(name: "Studio Workspace")
    accessible_workspace = Workspace.find_by!(name: "Client Workspace")
    private_workspace = Workspace.find_by!(name: "Private Workspace")
    folder = Folder.find_by!(name: "Product Docs")
    page = Page.find_by!(title: "Getting Started")
    root_recording = RecordingStudio::Recording.find_by!(recordable: workspace)
    accessible_root_recording = RecordingStudio::Recording.find_by!(recordable: accessible_workspace)
    private_root_recording = RecordingStudio::Recording.find_by!(recordable: private_workspace)
    folder_recording = RecordingStudio::Recording.find_by!(recordable: folder)
    page_recording = RecordingStudio::Recording.find_by!(recordable: page)
    publication = RecordingStudioPublications::Publication.find_by!(key: "the-atlantic")
    publication_recording = RecordingStudioPublications.recording_for(publication)
    workspace_article = RecordingStudioPublishedArticle::Queries::Collection.call(parent_recording: root_recording).detect do |recording|
      recording.recordable.title == "The Quiet Crop"
    end
    folder_article = RecordingStudioPublishedArticle::Queries::Collection.call(parent_recording: folder_recording).detect do |recording|
      recording.recordable.title == "Screens from the harvest"
    end

    assert_nil Current.actor
    assert_nil root_recording.parent_recording_id
    assert_nil accessible_root_recording.parent_recording_id
    assert_nil private_root_recording.parent_recording_id
    assert_equal root_recording, folder_recording.parent_recording
    assert_equal root_recording, folder_recording.root_recording
    assert_equal folder_recording, page_recording.parent_recording
    assert_equal root_recording, page_recording.root_recording
    assert_equal 3, Workspace.count
    assert_equal root_recording, workspace_article.parent_recording
    assert_equal folder_recording, folder_article.parent_recording
    assert_equal publication_recording.id, workspace_article.recordable.publication_recording_id
    assert RecordingStudioPublishedArticle.pdf_attachments(workspace_article).any?
    assert RecordingStudioPublishedArticle.screenshot_attachments(folder_article).any?
    assert ActiveRecord::Base.connection.table_exists?(:recording_studio_published_article_articles)
    refute ActiveRecord::Base.connection.column_exists?(:recording_studio_published_article_articles, :updated_at)

    assert_no_difference -> { User.count } do
      assert_no_difference -> { RecordingStudio::Recording.count } do
        load Rails.root.join("db/seeds.rb").to_s
      end
    end
    assert_nil Current.actor
  ensure
    Current.actor = nil
  end

  test "workspace opts into accessible and the example mixin without enabling them globally" do
    workspace_source = File.read(Rails.root.join("app/models/workspace.rb"))
    example_source = File.read(RecordingStudioPublishedArticle::Engine.root.join("lib/recording_studio_published_article/capabilities/example.rb"))

    assert_includes workspace_source, "include RecordingStudio::Capabilities::Example.to(label: \"dummy workspace\")"
    assert_includes example_source, "RecordingStudio::Capabilities.include_for(:example, **)"
    refute_includes example_source, "enable_capability"
    refute_includes example_source, "set_capability_options"

    assert RecordingStudio.capability_enabled?(:accessible, for: Workspace)
    assert RecordingStudio.capability_enabled?(:example, for: Workspace)
    assert_equal({ label: "dummy workspace" }, RecordingStudio.capability_options(:example, for: Workspace))
    refute RecordingStudio.capability_enabled?(:accessible, for: Folder)
    refute RecordingStudio.capability_enabled?(:accessible, for: Page)
    refute RecordingStudio.capability_enabled?(:example, for: Folder)
    refute RecordingStudio.capability_enabled?(:example, for: Page)
    assert_equal [ "Workspace" ], RecordingStudio.configuration.enabled_recordable_types_for(:example)
    assert_includes ApplicationController.ancestors, RecordingStudio::UsesDefaultLayout
  end
end
