# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
require_relative "test_helper"
require_relative "dummy/config/environment"
require "rails/test_help"
require_relative "support/article_test_helpers"

class PublishedArticleTest < ActiveSupport::TestCase
  include ArticleTestHelpers

  setup do
    @actor = create_actor
    Current.actor = @actor
    @root = workspace_root_for(unique_name("Article Workspace"), actor: @actor)
  end

  teardown do
    Current.actor = nil
  end

  test "title is required and url must be http or https with a host" do
    article = RecordingStudioPublishedArticle::PublishedArticle.new
    assert_not article.valid?
    assert_includes article.errors[:title], "can't be blank"

    article.title = "Titled"
    article.url = "ftp://example.com/nope"
    assert_not article.valid?
    assert_includes article.errors[:url], "must be an http or https URL"

    article.url = "https://"
    assert_not article.valid?

    article.url = "https://example.com/ok"
    assert article.valid?
  end

  test "publication_recording_id must point at a live publication recording" do
    article = RecordingStudioPublishedArticle::PublishedArticle.new(title: "Linked")
    article.publication_recording_id = @root.id
    assert_not article.valid?
    assert_includes article.errors[:publication_recording_id], "must point at a live publication"

    publication_recording = record_publication!(
      { name: unique_name("Mag"), key: "mag-#{SecureRandom.hex(4)}", kind: "magazine" },
      actor: @actor
    )
    article.publication_recording_id = publication_recording.id
    assert article.valid?
  end

  test "attachable is enabled on published article and not on the publication catalogue" do
    assert RecordingStudio.capability_enabled?(:attachable, for: "RecordingStudioPublishedArticle::PublishedArticle")
    refute RecordingStudio.capability_enabled?(:attachable, for: "RecordingStudioPublications::PublicationCatalogue")
  end

  test "articles nest under workspace and folder" do
    folder_recording = record_folder(@root, unique_name("Docs"))
    workspace_article = record_article!(@root, { title: unique_name("Workspace copy") }, actor: @actor)
    folder_article = record_article!(folder_recording, { title: unique_name("Folder copy") }, actor: @actor)

    assert_equal @root, workspace_article.parent_recording
    assert_equal folder_recording, folder_article.parent_recording
    assert_equal @root, folder_article.root_recording
  end

  test "recording under root without parent_recording nests under the root" do
    recording = @root.record(RecordingStudioPublishedArticle::PublishedArticle, actor: @actor) do |article|
      article.title = unique_name("Root default parent")
    end

    assert_equal @root, recording.parent_recording
  end

  test "pdf_attachments and screenshot_attachments split copies by kind and content type" do
    article = record_article!(@root, { title: unique_name("Copies") }, actor: @actor)
    attach_copy!(
      article,
      filename: "page.png",
      content_type: "image/png",
      io: ONE_PIXEL_PNG,
      actor: @actor
    )
    attach_copy!(
      article,
      filename: "page.pdf",
      content_type: "application/pdf",
      io: MINIMAL_PDF,
      actor: @actor
    )

    pdfs = RecordingStudioPublishedArticle.pdf_attachments(article)
    screenshots = RecordingStudioPublishedArticle.screenshot_attachments(article)

    assert_equal(["page.pdf"], pdfs.map { |recording| recording.recordable.original_filename })
    assert_equal(["page.png"], screenshots.map { |recording| recording.recordable.original_filename })
  end

  test "publication_recording_for returns a publication recording and ignores other recordings" do
    publication_recording = record_publication!(
      { name: unique_name("Title"), key: "title-#{SecureRandom.hex(4)}", kind: "newspaper" },
      actor: @actor
    )
    publication = publication_recording.recordable

    assert_equal publication_recording, RecordingStudioPublishedArticle.publication_recording_for(publication_recording)
    assert_equal publication_recording, RecordingStudioPublishedArticle.publication_recording_for(publication)
    assert_nil RecordingStudioPublishedArticle.publication_recording_for(@root)
  end

  test "import_attachment stores a png and a pdf on an article" do
    article = record_article!(@root, { title: unique_name("Imported") }, actor: @actor)
    attach_copy!(article, filename: "shot.png", content_type: "image/png", io: ONE_PIXEL_PNG, actor: @actor)
    attach_copy!(article, filename: "copy.pdf", content_type: "application/pdf", io: MINIMAL_PDF, actor: @actor)

    assert_equal 1, RecordingStudioPublishedArticle.screenshot_attachments(article).size
    assert_equal 1, RecordingStudioPublishedArticle.pdf_attachments(article).size
  end
end
