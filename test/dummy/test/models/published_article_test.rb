# frozen_string_literal: true

require "test_helper"

class PublishedArticleTest < ActiveSupport::TestCase
  setup do
    @actor = create_actor
    Current.actor = @actor
    @root = workspace_root_for(unique_name("Article Workspace"), actor: @actor)
    @folder = record_folder(@root, unique_name("Article Folder"))
  end

  teardown do
    Current.actor = nil
  end

  test "article is a nested type and cannot be a root" do
    declaration = RecordingStudio.recordable_declaration_for("RecordingStudioPublishedArticle::PublishedArticle")

    assert RecordingStudio.validate_recordable_declarations!
    refute declaration.root?
    assert_equal "Article", declaration.label
    assert_equal "Articles", declaration.plural_label
    assert_equal %w[Workspace Folder RecordingStudioPublications::Publication], declaration.allowed_parent_types
    refute RecordingStudio.capability_enabled?(:example, for: RecordingStudioPublishedArticle::PublishedArticle)
    assert RecordingStudio.capability_enabled?(:attachable, for: RecordingStudioPublishedArticle::PublishedArticle)

    article = RecordingStudioPublishedArticle::PublishedArticle.create!(title: unique_name("Orphan"))
    assert_raises(RecordingStudio::RootNotAllowed) do
      RecordingStudio.root_recording_for(article)
    end
  end

  test "articles are rejected under a page" do
    page = record_page(@root, @root, unique_name("Parent Page"))

    error = assert_raises(RecordingStudio::InvalidParent) do
      record_article!(page, { title: unique_name("Nested under page") }, actor: @actor)
    end

    assert_match(/PublishedArticle cannot be recorded under Page/, error.message)
  end

  test "an empty parent list rejects workspace and folder parents" do
    original = RecordingStudioPublishedArticle.article_parent_types
    RecordingStudioPublishedArticle.article_parent_types = []

    error = assert_raises(RecordingStudio::InvalidParent) do
      record_article!(@root, { title: unique_name("Blocked") }, actor: @actor)
    end
    assert_match(/PublishedArticle cannot be recorded under Workspace/, error.message)
  ensure
    RecordingStudioPublishedArticle.article_parent_types = original
  end

  test "workspace and folder both accept articles" do
    workspace_article = record_article!(
      @root,
      {
        title: "Quiet crop under workspace",
        url: "https://example.com/quiet-crop",
        published_at: Time.utc(2024, 3, 12),
        author: "Ada Staff",
        excerpt: "A short pull-quote."
      },
      actor: @actor
    )
    folder_article = record_article!(
      @folder,
      {
        title: "Harvest screens under folder",
        url: "https://example.com/harvest",
        published_at: Time.utc(2024, 6, 2),
        author: "Ada Staff"
      },
      actor: @actor
    )

    assert_equal @root, workspace_article.parent_recording
    assert_equal @folder, folder_article.parent_recording
    assert_equal @root, workspace_article.root_recording
    assert_equal @root, folder_article.root_recording
    assert_equal "Quiet crop under workspace", workspace_article.recordable.title
    assert_equal "Harvest screens under folder", folder_article.recordable.title

    workspace_titles = RecordingStudioPublishedArticle::Queries::Collection.call(parent_recording: @root).map { |recording| recording.recordable.title }
    folder_titles = RecordingStudioPublishedArticle::Queries::Collection.call(parent_recording: @folder).map { |recording| recording.recordable.title }

    assert_equal ["Quiet crop under workspace"], workspace_titles
    assert_equal ["Harvest screens under folder"], folder_titles
  end

  test "a publication parent is allowed and stays distinct from the publication reference" do
    publication = record_publication!(
      { name: unique_name("Archive Mag"), kind: "magazine" },
      actor: @actor
    )
    archive = record_article!(
      publication,
      {
        title: unique_name("Archive copy"),
        publication_recording_id: publication.id
      },
      actor: @actor
    )

    archive_titles = RecordingStudioPublishedArticle::Queries::Collection.call(
      parent_recording: publication
    ).map { |recording| recording.recordable.title }

    assert_equal publication, archive.parent_recording
    assert_equal publication.id, archive.recordable.publication_recording_id
    assert_equal [archive.recordable.title], archive_titles
    refute_includes RecordingStudioPublishedArticle::Queries::Collection.call(parent_recording: @root).map { |recording|
      recording.recordable.title
    }, archive.recordable.title
  end

  test "publication_recording_id stores the publication recording id" do
    publication = record_publication!(
      { name: unique_name("The Atlantic"), kind: "magazine", website: "https://www.theatlantic.com" },
      actor: @actor
    )
    looked_up = RecordingStudioPublishedArticle.publication_recording_for(publication.recordable)

    article = record_article!(
      @root,
      {
        title: unique_name("Quiet crop"),
        publication_recording_id: looked_up.id
      },
      actor: @actor
    )

    assert_equal publication.id, article.recordable.publication_recording_id
    assert_equal publication.id, article.recordable.publication_recording.id
    assert_equal publication.recordable.name, article.recordable.publication_name

    error = assert_raises(ActiveRecord::RecordInvalid) do
      record_article!(@root, { title: unique_name("Bad publication"), publication_recording_id: @root.id }, actor: @actor)
    end
    assert_match(/live publication/, error.message)
  end

  test "url only, pdf only, screenshot only, and combinations are valid" do
    url_only = record_article!(
      @root,
      { title: unique_name("URL only"), url: "https://example.com/url-only" },
      actor: @actor
    )
    pdf_only = record_article!(@root, { title: unique_name("PDF only") }, actor: @actor)
    screenshot_only = record_article!(@root, { title: unique_name("Screenshot only") }, actor: @actor)
    both = record_article!(
      @root,
      { title: unique_name("Both copies"), url: "https://example.com/both" },
      actor: @actor
    )

    attach_copy!(
      pdf_only,
      filename: "copy.pdf",
      content_type: "application/pdf",
      io: MINIMAL_PDF,
      actor: @actor
    )
    attach_copy!(
      screenshot_only,
      filename: "page.png",
      content_type: "image/png",
      io: ONE_PIXEL_PNG,
      actor: @actor
    )
    attach_copy!(
      both,
      filename: "copy.pdf",
      content_type: "application/pdf",
      io: MINIMAL_PDF,
      actor: @actor
    )
    attach_copy!(
      both,
      filename: "page.png",
      content_type: "image/png",
      io: ONE_PIXEL_PNG,
      actor: @actor
    )

    assert_equal "https://example.com/url-only", url_only.recordable.url
    assert_empty RecordingStudioPublishedArticle.pdf_attachments(url_only)
    assert_empty RecordingStudioPublishedArticle.screenshot_attachments(url_only)

    assert_equal 1, RecordingStudioPublishedArticle.pdf_attachments(pdf_only).size
    assert_empty RecordingStudioPublishedArticle.screenshot_attachments(pdf_only)

    assert_equal 1, RecordingStudioPublishedArticle.screenshot_attachments(screenshot_only).size
    assert_empty RecordingStudioPublishedArticle.pdf_attachments(screenshot_only)

    assert_equal 1, RecordingStudioPublishedArticle.pdf_attachments(both).size
    assert_equal 1, RecordingStudioPublishedArticle.screenshot_attachments(both).size
  end

  test "an invalid url is rejected" do
    error = assert_raises(ActiveRecord::RecordInvalid) do
      record_article!(@root, { title: unique_name("Bad url"), url: "ftp://example.com/x" }, actor: @actor)
    end
    assert_match(/http or https URL/, error.message)

    error = assert_raises(ActiveRecord::RecordInvalid) do
      record_article!(@root, { title: unique_name("Not a url"), url: "not-a-url" }, actor: @actor)
    end
    assert_match(/http or https URL/, error.message)
  end

  test "revise writes a new snapshot on the same recording" do
    article = record_article!(
      @root,
      { title: unique_name("Revise me"), excerpt: "First pull-quote." },
      actor: @actor
    )
    original_id = article.recordable.id

    revised = @root.revise(article, actor: @actor) do |snapshot|
      snapshot.excerpt = "Updated pull-quote."
    end

    assert_equal article.id, revised.id
    assert_equal "Updated pull-quote.", revised.recordable.excerpt
    refute_equal original_id, revised.recordable.id
  end

  test "collection filters, sorts, and extra_scope" do
    publication = record_publication!({ name: unique_name("Filter Mag"), kind: "journal" }, actor: @actor)
    other_publication = record_publication!({ name: unique_name("Other Mag"), kind: "site" }, actor: @actor)

    crop = record_article!(
      @root,
      {
        title: "The Quiet Crop",
        url: "https://example.com/crop",
        published_at: Time.utc(2024, 3, 12),
        author: "Ada Staff",
        excerpt: "A field note.",
        publication_recording_id: publication.id
      },
      actor: @actor
    )
    later = record_article!(
      @root,
      {
        title: "Zebra harvest",
        published_at: Time.utc(2023, 11, 8),
        author: "Bea Editor",
        publication_recording_id: other_publication.id
      },
      actor: @actor
    )
    record_article!(
      @folder,
      { title: "Folder crop", published_at: Time.utc(2024, 1, 1), author: "Ada Staff" },
      actor: @actor
    )

    attach_copy!(crop, filename: "crop.pdf", content_type: "application/pdf", io: MINIMAL_PDF, actor: @actor)
    attach_copy!(later, filename: "later.png", content_type: "image/png", io: ONE_PIXEL_PNG, actor: @actor)

    titles = ->(filters: {}, extra_scope: nil, sort: :published_at_desc) {
      RecordingStudioPublishedArticle::Queries::Collection.call(
        parent_recording: @root,
        filters: filters,
        extra_scope: extra_scope,
        sort: sort
      ).map { |recording| recording.recordable.title }
    }

    assert_equal ["The Quiet Crop", "Zebra harvest"], titles.call
    assert_equal ["Zebra harvest", "The Quiet Crop"], titles.call(sort: :published_at_asc)
    assert_equal ["The Quiet Crop", "Zebra harvest"], titles.call(sort: :title)
    assert_equal ["The Quiet Crop"], titles.call(filters: { q: "CROP" })
    assert_equal ["The Quiet Crop"], titles.call(filters: { author: "Ada Staff" })
    assert_equal ["The Quiet Crop"], titles.call(filters: { year: 2024 })
    assert_equal ["The Quiet Crop"], titles.call(filters: { published_from: Time.utc(2024, 1, 1) })
    assert_equal ["Zebra harvest"], titles.call(filters: { published_to: Time.utc(2023, 12, 31) })
    assert_equal ["The Quiet Crop"], titles.call(filters: { has_url: true })
    assert_equal ["Zebra harvest"], titles.call(filters: { has_url: false })
    assert_equal ["The Quiet Crop"], titles.call(filters: { publication_recording_id: publication.id })
    assert_equal ["The Quiet Crop"], titles.call(filters: { attachment_kind: :pdf })
    assert_equal ["Zebra harvest"], titles.call(filters: { attachment_kind: :image })
    assert_equal ["The Quiet Crop"], titles.call(filters: { attachment_kind: :file })
    assert_equal ["The Quiet Crop", "Zebra harvest"], titles.call(filters: { attachment_kind: :any })
    assert_empty titles.call(filters: { attachment_kind: :none })
    assert_equal ["The Quiet Crop"], titles.call(extra_scope: ->(relation) { relation.where(id: crop.id) })
    assert_equal ["The Quiet Crop", "Zebra harvest"], titles.call(extra_scope: ->(_relation) { :not_a_relation })
    assert_empty RecordingStudioPublishedArticle::Queries::Collection.call(parent_recording: nil)
  end
end
