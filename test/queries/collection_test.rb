# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
require_relative "../test_helper"
require_relative "../dummy/config/environment"
require "rails/test_help"
require_relative "../support/article_test_helpers"

class CollectionQueryTest < ActiveSupport::TestCase
  include ArticleTestHelpers

  Collection = RecordingStudioPublishedArticle::Queries::Collection

  setup do
    @actor = create_actor(email_prefix: "collection")
    Current.actor = @actor
    seed_collection_articles
  end

  teardown do
    Current.actor = nil
  end

  test "lists direct children of a workspace and a folder as separate collections" do
    workspace_titles = titles_for(Collection.call(parent_recording: @root))
    folder_titles = titles_for(Collection.call(parent_recording: @folder))

    assert_includes workspace_titles, "Alpha url only"
    refute_includes workspace_titles, "Folder harvest"
    assert_equal ["Folder harvest"], folder_titles
  end

  test "filters by publication, author, year, date range, search, and has_url" do
    by_publication = titles_for(Collection.call(
                                  parent_recording: @root,
                                  filters: { publication_recording_id: @atlantic.id }
                                ))
    assert_includes by_publication, "Alpha url only"
    refute_includes by_publication, "Bravo pdf only"

    by_author = titles_for(Collection.call(parent_recording: @root, filters: { author: "Bea Line" }))
    assert_equal ["Bravo pdf only"], by_author

    by_year = titles_for(Collection.call(parent_recording: @root, filters: { year: 2023 }))
    assert_equal ["Bravo pdf only"], by_year

    by_range = titles_for(Collection.call(
                            parent_recording: @root,
                            filters: { published_from: Time.utc(2024, 1, 1), published_to: Time.utc(2024, 2, 1) }
                          ))
    assert_equal ["Alpha url only"], by_range

    by_search = titles_for(Collection.call(parent_recording: @root, filters: { q: "CROP" }))
    assert_equal ["Alpha url only"], by_search

    with_url = titles_for(Collection.call(parent_recording: @root, filters: { has_url: true }))
    without_url = titles_for(Collection.call(parent_recording: @root, filters: { has_url: false }))
    assert_includes with_url, "Alpha url only"
    refute_includes with_url, "Bravo pdf only"
    assert_includes without_url, "Bravo pdf only"
    refute_includes without_url, "Alpha url only"
  end

  test "filters by attachment kind including pdf vs screenshot vs none" do
    images = titles_for(Collection.call(parent_recording: @root, filters: { attachment_kind: :image }))
    files = titles_for(Collection.call(parent_recording: @root, filters: { attachment_kind: :file }))
    pdfs = titles_for(Collection.call(parent_recording: @root, filters: { attachment_kind: :pdf }))
    none = titles_for(Collection.call(parent_recording: @root, filters: { attachment_kind: :none }))
    any = titles_for(Collection.call(parent_recording: @root, filters: { attachment_kind: :any }))

    assert_equal ["Charlie screenshot only"], images
    assert_equal ["Bravo pdf only"], files
    assert_equal ["Bravo pdf only"], pdfs
    assert_includes none, "Alpha url only"
    assert_includes none, "Zed undated"
    refute_includes none, "Bravo pdf only"
    refute_includes none, "Charlie screenshot only"
    assert_includes any, "Alpha url only"
    assert_includes any, "Bravo pdf only"
  end

  test "sorts by published_at with nulls last and by title" do
    desc = titles_for(Collection.call(parent_recording: @root, sort: :published_at_desc))
    asc = titles_for(Collection.call(parent_recording: @root, sort: :published_at_asc))
    titled = titles_for(Collection.call(parent_recording: @root, sort: :title))

    assert_equal "Charlie screenshot only", desc.first
    assert_equal "Zed undated", desc.last
    assert_equal "Bravo pdf only", asc.first
    assert_equal "Zed undated", asc.last
    assert_equal "Alpha url only", titled.first
    assert_equal "Zed undated", titled.last
  end

  test "extra_scope receives the recording relation and unknown sort defaults to published_at_desc" do
    scoped = Collection.call(
      parent_recording: @root,
      extra_scope: ->(relation) { relation.where(id: @url_only.id) }
    )
    assert_equal ["Alpha url only"], titles_for(scoped)

    ignored = Collection.call(parent_recording: @root, extra_scope: ->(_relation) { :not_a_relation })
    assert_includes titles_for(ignored), "Alpha url only"

    defaulted = titles_for(Collection.call(parent_recording: @root, sort: :nope))
    assert_equal "Charlie screenshot only", defaulted.first
  end

  test "blank parent returns none" do
    assert_empty Collection.call(parent_recording: nil)
  end

  test "blank unknown and invalid filter values do not hide rows" do
    titles = titles_for(Collection.call(
                          parent_recording: @root,
                          filters: {
                            year: 0,
                            has_url: "",
                            published_from: "not-a-date",
                            attachment_kind: :banana
                          },
                          extra_scope: :not_callable
                        ))

    assert_includes titles, "Alpha url only"
    assert_includes titles, "Bravo pdf only"
    assert_includes titles, "Charlie screenshot only"
  end

  test "url pdf screenshot and combinations stay valid articles" do
    combo = record_article!(
      @root,
      { title: unique_name("Combo"), url: "https://example.com/combo" },
      actor: @actor
    )
    attach_copy!(combo, filename: "combo.pdf", content_type: "application/pdf", io: MINIMAL_PDF, actor: @actor)
    attach_copy!(combo, filename: "combo.png", content_type: "image/png", io: ONE_PIXEL_PNG, actor: @actor)

    pdfs = titles_for(Collection.call(parent_recording: @root, filters: { attachment_kind: :pdf }))
    images = titles_for(Collection.call(parent_recording: @root, filters: { attachment_kind: :image }))
    with_url = titles_for(Collection.call(parent_recording: @root, filters: { has_url: true }))

    assert_includes pdfs, combo.recordable.title
    assert_includes images, combo.recordable.title
    assert_includes with_url, combo.recordable.title
  end

  private

  def seed_collection_articles
    @root = workspace_root_for(unique_name("Collection Workspace"), actor: @actor)
    @folder = record_folder(@root, unique_name("Collection Folder"))
    @atlantic = record_publication!(
      { name: unique_name("Atlantic"), key: "atlantic-#{SecureRandom.hex(4)}", kind: "magazine" },
      actor: @actor
    )
    @guardian = record_publication!(
      { name: unique_name("Guardian"), key: "guardian-#{SecureRandom.hex(4)}", kind: "newspaper" },
      actor: @actor
    )

    @url_only = record_article!(
      @root,
      {
        title: "Alpha url only",
        url: "https://example.com/alpha",
        published_at: Time.utc(2024, 1, 10),
        author: "Ada Staff",
        excerpt: "crop in the excerpt",
        publication_recording_id: @atlantic.id
      },
      actor: @actor
    )
    @pdf_only = record_article!(
      @root,
      {
        title: "Bravo pdf only",
        published_at: Time.utc(2023, 6, 1),
        author: "Bea Line",
        excerpt: "notes",
        publication_recording_id: @guardian.id
      },
      actor: @actor
    )
    attach_copy!(@pdf_only, filename: "bravo.pdf", content_type: "application/pdf", io: MINIMAL_PDF, actor: @actor)

    @screenshot_only = record_article!(
      @root,
      {
        title: "Charlie screenshot only",
        published_at: Time.utc(2024, 8, 2),
        author: "Ada Staff",
        excerpt: "still"
      },
      actor: @actor
    )
    attach_copy!(
      @screenshot_only,
      filename: "charlie.png",
      content_type: "image/png",
      io: ONE_PIXEL_PNG,
      actor: @actor
    )

    @undated = record_article!(
      @root,
      { title: "Zed undated", author: "Ada Staff" },
      actor: @actor
    )

    @folder_article = record_article!(
      @folder,
      {
        title: "Folder harvest",
        url: "https://example.com/folder",
        published_at: Time.utc(2024, 3, 3),
        author: "Ada Staff",
        publication_recording_id: @atlantic.id
      },
      actor: @actor
    )
    attach_copy!(
      @folder_article,
      filename: "folder.png",
      content_type: "image/png",
      io: ONE_PIXEL_PNG,
      actor: @actor
    )
  end

  def titles_for(relation)
    relation.map { |recording| recording.recordable.title }
  end
end
