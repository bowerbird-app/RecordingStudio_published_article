# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
require_relative "test_helper"
require_relative "dummy/config/environment"

require "rails/test_help"

class RecordingStudioDeclarationsTest < ActiveSupport::TestCase
  test "dummy recordable declarations validate and expose parent/root introspection" do
    assert RecordingStudio.validate_recordable_declarations!
    assert_includes RecordingStudio.root_recordable_types, "Workspace"
    assert_includes RecordingStudio.root_recordable_types, "RecordingStudioPublications::PublicationCatalogue"
    assert_equal %w[Workspace Folder], RecordingStudio.allowed_parent_types_for("Folder")
    assert_equal %w[Workspace Folder], RecordingStudio.allowed_parent_types_for(Page)
    assert_equal %w[Workspace Folder RecordingStudioPublications::Publication],
                 RecordingStudio.allowed_parent_types_for("RecordingStudioPublishedArticle::PublishedArticle")
  end

  test "root recordable creates a root recording" do
    workspace = Workspace.create!(name: unique_name("Root Workspace"))

    root_recording = RecordingStudio.root_recording_for(workspace)

    assert_predicate root_recording, :persisted?
    assert_equal workspace, root_recording.recordable
    assert_nil root_recording.parent_recording_id
    assert_equal root_recording.id, root_recording.root_recording_id
  end

  test "allowed child can be recorded under a workspace root" do
    root_recording = RecordingStudio.root_recording_for(Workspace.create!(name: unique_name("Child Workspace")))
    folder = Folder.new(name: unique_name("Allowed Folder"))

    event = RecordingStudio.record!(
      action: "created",
      recordable: folder,
      root_recording: root_recording,
      parent_recording: root_recording
    )

    assert_equal folder, event.recording.recordable
    assert_equal root_recording, event.recording.parent_recording
  end

  test "page can be recorded under allowed workspace and folder parents" do
    root_recording = RecordingStudio.root_recording_for(Workspace.create!(name: unique_name("Page Workspace")))
    folder_recording = record_child(Folder.new(name: unique_name("Page Folder")), root_recording, root_recording)

    workspace_page_recording = record_child(
      Page.new(title: unique_name("Workspace Page")),
      root_recording,
      root_recording
    )
    folder_page_recording = record_child(Page.new(title: unique_name("Folder Page")), root_recording, folder_recording)

    assert_equal root_recording, workspace_page_recording.parent_recording
    assert_equal folder_recording, folder_page_recording.parent_recording
  end

  test "child recordable cannot be created as a root" do
    folder = Folder.create!(name: unique_name("Root Rejected Folder"))

    assert_raises(RecordingStudio::RootNotAllowed) do
      RecordingStudio.root_recording_for(folder)
    end
  end

  test "parentless child under an existing root is invalid" do
    root_recording = RecordingStudio.root_recording_for(Workspace.create!(name: unique_name("Parentless Workspace")))
    folder = Folder.create!(name: unique_name("Parentless Folder"))
    recording = RecordingStudio::Recording.new(root_recording: root_recording, recordable: folder)

    assert_not recording.valid?
    assert_includes recording.errors[:parent_recording_id].join, "cannot be blank"
  end

  test "page cannot be recorded under another page" do
    root_recording = RecordingStudio.root_recording_for(Workspace.create!(name: unique_name("Invalid Page Workspace")))
    page_recording = record_child(Page.new(title: unique_name("Parent Page")), root_recording, root_recording)

    error = assert_raises(RecordingStudio::InvalidParent) do
      record_child(Page.new(title: unique_name("Nested Page")), root_recording, page_recording)
    end
    assert_equal "Page cannot be recorded under Page", error.message
  end

  test "accessible is enabled on workspace and example mixin stays opt-in" do
    assert RecordingStudio.capability_enabled?(:accessible, for: "Workspace")
    refute RecordingStudio.capability_enabled?(:accessible, for: "Folder")
    refute RecordingStudio.capability_enabled?(:accessible, for: "Page")

    assert RecordingStudio.capability_enabled?(:example, for: "Workspace")
    refute RecordingStudio.capability_enabled?(:example, for: "Folder")
    refute RecordingStudio.capability_enabled?(:example, for: "Page")
    refute RecordingStudio.capability_enabled?(:example, for: "RecordingStudioPublishedArticle::PublishedArticle")
    assert_equal({ label: "dummy workspace" }, RecordingStudio.capability_options(:example, for: "Workspace"))
    assert RecordingStudio.capability_enabled?(:attachable, for: "RecordingStudioPublishedArticle::PublishedArticle")
  end

  test "published articles nest under workspace and folder" do
    actor = User.create!(
      email: "declarations-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    Current.actor = actor
    root_recording = RecordingStudio.root_recording_for(Workspace.create!(name: unique_name("Article Workspace")))
    folder_recording = record_child(Folder.new(name: unique_name("Article Folder")), root_recording, root_recording)

    workspace_article = root_recording.record(
      RecordingStudioPublishedArticle::PublishedArticle,
      actor: actor
    ) do |article|
      article.title = unique_name("Workspace article")
    end
    folder_article = root_recording.record(
      RecordingStudioPublishedArticle::PublishedArticle,
      actor: actor,
      parent_recording: folder_recording
    ) do |article|
      article.title = unique_name("Folder article")
    end

    assert_equal root_recording, workspace_article.parent_recording
    assert_equal folder_recording, folder_article.parent_recording
  ensure
    Current.actor = nil
  end

  private

  def record_child(recordable, root_recording, parent_recording)
    RecordingStudio.record!(
      action: "created",
      recordable: recordable,
      root_recording: root_recording,
      parent_recording: parent_recording
    ).recording
  end

  def unique_name(prefix)
    "#{prefix} #{SecureRandom.hex(4)}"
  end
end
