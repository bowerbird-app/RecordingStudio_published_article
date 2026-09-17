# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class ArticlesTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @actor = create_actor(email_prefix: "ui")
    Current.actor = @actor
    @root = workspace_root_for(unique_name("UI Workspace"), actor: @actor)
    @folder = record_folder(@root, unique_name("UI Folder"))
    publication = record_publication!({ name: unique_name("Filter Mag"), kind: "magazine" }, actor: @actor)

    @workspace_article = record_article!(
      @root,
      {
        title: "The Quiet Crop",
        url: "https://example.com/quiet-crop",
        published_at: Time.utc(2024, 3, 12),
        author: "Ada Staff",
        excerpt: "A short pull-quote from the field.",
        publication_recording_id: publication.id
      },
      actor: @actor
    )
    attach_copy!(
      @workspace_article,
      filename: "quiet-crop.pdf",
      content_type: "application/pdf",
      io: MINIMAL_PDF,
      actor: @actor
    )

    @folder_article = record_article!(
      @folder,
      {
        title: "Screens from the harvest",
        url: "https://example.com/harvest-screens",
        published_at: Time.utc(2024, 6, 2),
        author: "Ada Staff"
      },
      actor: @actor
    )
    attach_copy!(
      @folder_article,
      filename: "harvest.png",
      content_type: "image/png",
      io: ONE_PIXEL_PNG,
      actor: @actor
    )

    sign_in @actor
  end

  teardown do
    Current.actor = nil
  end

  test "index lists workspace articles in a table and can switch to cards" do
    get recording_studio_published_article.recording_articles_path(@root)

    assert_response :success
    assert_select "h1", text: "Articles"
    assert_includes response.body, "The Quiet Crop"
    refute_includes response.body, "Screens from the harvest"
    refute_includes response.body, "recordable"
    assert_includes response.body, "PDF"
    assert_includes response.body, "Show articles"

    get recording_studio_published_article.recording_articles_path(@root, view: "cards")
    assert_response :success
    assert_includes response.body, "The Quiet Crop"
  end

  test "index lists articles under a publication parent" do
    publication = record_publication!(
      { name: unique_name("Archive Mag"), kind: "magazine" },
      actor: @actor
    )
    record_article!(
      publication,
      {
        title: "Archive copy under the title",
        publication_recording_id: publication.id
      },
      actor: @actor
    )

    get recording_studio_published_article.recording_articles_path(publication)

    assert_response :success
    assert_includes response.body, "Archive copy under the title"
    refute_includes response.body, "The Quiet Crop"
  end

  test "index lists folder articles separately" do
    get recording_studio_published_article.recording_articles_path(@folder)

    assert_response :success
    assert_includes response.body, "Screens from the harvest"
    refute_includes response.body, "The Quiet Crop"
    assert_includes response.body, "Screenshot"
  end

  test "index filters by search author and has_url" do
    record_article!(
      @root,
      { title: "No url copy", author: "Bea Line" },
      actor: @actor
    )

    get recording_studio_published_article.recording_articles_path(@root, q: "crop")
    assert_response :success
    assert_includes response.body, "The Quiet Crop"

    get recording_studio_published_article.recording_articles_path(@root, author: "Bea Line")
    assert_response :success
    assert_includes response.body, "No url copy"
    refute_includes response.body, "The Quiet Crop"

    get recording_studio_published_article.recording_articles_path(@root, has_url: "false")
    assert_response :success
    assert_includes response.body, "No url copy"
    refute_includes response.body, "The Quiet Crop"
  end

  test "detail shows attributes, pdf download, and attachable paths" do
    get recording_studio_published_article.article_path(@workspace_article)

    assert_response :success
    assert_includes response.body, "The Quiet Crop"
    assert_includes response.body, "Ada Staff"
    assert_includes response.body, "https://example.com/quiet-crop"
    assert_includes response.body, "PDFs"
    assert_includes response.body, "/recording_studio_attachable/attachments/"
    refute_includes response.body, "/rails/active_storage/blobs"
    refute_includes response.body, "recordable"
  end

  test "detail shows screenshot images through attachable preview paths" do
    get recording_studio_published_article.article_path(@folder_article)

    assert_response :success
    assert_includes response.body, "Screens from the harvest"
    assert_includes response.body, "Screenshots"
    assert_includes response.body, "/recording_studio_attachable/attachments/"
    assert_includes response.body, "/preview/"
  end

  test "detail omits screenshot and pdf sections when the article has no copies" do
    bare = record_article!(
      @root,
      { title: "Bare url only", url: "https://example.com/bare" },
      actor: @actor
    )

    get recording_studio_published_article.article_path(bare)

    assert_response :success
    assert_includes response.body, "Bare url only"
    refute_includes response.body, "Screenshots"
    refute_includes response.body, "PDFs"
  end

  test "unknown article ids are not found" do
    get recording_studio_published_article.article_path(@root)

    assert_response :not_found
  end

  test "missing parents are not found" do
    get recording_studio_published_article.recording_articles_path("00000000-0000-0000-0000-000000000000")

    assert_response :not_found
  end

  test "a signed-in stranger cannot view another workspace index" do
    stranger = create_actor(email_prefix: "stranger")
    sign_in stranger

    get recording_studio_published_article.recording_articles_path(@root)

    assert_response :forbidden
  end

  test "engine root answers ok" do
    get recording_studio_published_article.root_path

    assert_response :ok
  end

  test "index filter bar names search publication year and author" do
    get recording_studio_published_article.recording_articles_path(@root, year: 2024, q: "crop")

    assert_response :success
    assert_includes response.body, "The Quiet Crop"
    assert_includes response.body, "Search"
    assert_includes response.body, "Publication"
    assert_includes response.body, "Year"
    assert_includes response.body, "Author"
  end
end
