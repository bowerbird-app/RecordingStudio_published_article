# Published Articles

A Recording Studio addon that stores a published article as a nested recordable. The parent is why you saved it. The publication directory is which title printed it. PDFs and screenshots are Attachable children.

This gem does not crawl the web, capture screenshots, or model Featured In.

Current version is **0.3.0**.

## Install

1. Add the gem and sibling pins.

```ruby
gem "recording_studio_published_article"
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v4.2.0"
gem "recording_studio_publications", github: "bowerbird-app/RecordingStudio_publications", tag: "v0.2.1"
gem "recording_studio_attachable", github: "bowerbird-app/RecordingStudio_attachable", tag: "v0.5.1"
```

2. Install and migrate.

```bash
bin/rails generate recording_studio_published_article:install
bin/rails generate recording_studio_publications:migrations
bin/rails generate recording_studio_attachable:install
bin/rails generate recording_studio_attachable:migrations
bin/rails generate recording_studio_published_article:migrations
bin/rails db:migrate
```

3. Register types in the host Recording Studio initializer.

```ruby
RecordingStudio.configure do |config|
  config.recordable_types = [
    "Workspace",
    "Folder",
    "RecordingStudioPublications::PublicationCatalogue",
    "RecordingStudioPublications::Publication",
    "RecordingStudioPublishedArticle::PublishedArticle",
    "RecordingStudioAttachable::Attachment"
  ]
  config.require_recordable_declarations = true
end
```

4. Set allowed parents. The default list is empty.

```ruby
RecordingStudioPublishedArticle.configure do |config|
  config.article_parent_types = %w[Workspace Folder RecordingStudioPublications::Publication]
end
```

5. Mount the engines.

```ruby
mount RecordingStudioPublishedArticle::Engine, at: "/recording_studio_published_article"
mount RecordingStudioAttachable::Engine, at: "/recording_studio_attachable"
```

Mount Attachable so PDF and screenshot links use authorized engine paths. Do not mint raw blob URLs.

## Record an article

Write through the parent. Pass `parent_recording:` when the parent is not the root.

```ruby
root = workspace_recording
root.record(RecordingStudioPublishedArticle::PublishedArticle) do |article|
  article.title = "The Quiet Crop"
  article.url = "https://example.com/quiet-crop"
  article.published_at = Time.utc(2024, 3, 12)
  article.author = "Ada Staff"
  article.excerpt = "A short pull-quote."
  article.publication_recording_id = RecordingStudioPublishedArticle.publication_recording_for(publication).id
end

root.record(
  RecordingStudioPublishedArticle::PublishedArticle,
  parent_recording: folder_recording
) do |article|
  article.title = "Folder copy"
end
```

`publication_recording_id` is the Publication recording id, not the snapshot row id. Title is required. URL, date, author, excerpt, and publication are optional. URL must be http or https when present.

Revise makes a new snapshot.

```ruby
root.revise(article_recording) do |article|
  article.excerpt = "Updated pull-quote."
end
```

## Attach a PDF or screenshot

Do this after the article exists. Attachable classifies by content type. A screenshot is an image. A PDF is a file.

```ruby
article_recording.import_attachment(io: png, filename: "page.png", content_type: "image/png")
article_recording.import_attachment(io: pdf, filename: "page.pdf", content_type: "application/pdf")

RecordingStudioPublishedArticle.screenshot_attachments(article_recording)
RecordingStudioPublishedArticle.pdf_attachments(article_recording)
```

URL-only, PDF-only, screenshot-only, and combinations are all valid.

## Index articles for a parent

```ruby
recordings = RecordingStudioPublishedArticle::Queries::Collection.call(
  parent_recording: parent_recording,
  filters: { year: 2024, q: "crop", attachment_kind: :pdf },
  extra_scope: ->(relation) { relation },
  sort: :published_at_desc
)
```

Filters are `publication_recording_id`, `author`, `year`, `published_from`, `published_to`, `q` (title, author, excerpt), `has_url`, and `attachment_kind` (`:image`, `:file`, `:pdf`, `:none`, `:any`). Sort is `:published_at_desc` (default), `:published_at_asc`, or `:title`. `extra_scope` receives the Recording relation so the host can add scopes without changing this gem.

Render the shipped index.

```erb
<%= render RecordingStudioPublishedArticle::Articles::IndexComponent.new(
  article_recordings: recordings,
  parent_recording: parent_recording,
  filters: filters,
  show_path: ->(recording) { recording_studio_published_article.article_path(recording) }
) %>
```

Engine routes, mounted at `/recording_studio_published_article`:

- `GET recordings/:recording_id/articles` lists articles for that parent
- `GET articles/:id` shows one article

## Dummy host

`test/dummy` proves the gem. Sign in at `/users/sign_in` with `admin@admin.com` / `Password`. Home shows three indexes: the studio workspace, the Product Docs folder, and The Atlantic. Family pins stay Recording Studio `v4.2.0`, Accessible `v0.9.1`, Root Switchable `v0.5.0`, and Flatpack `v0.1.177`.

## Boundaries

This gem does not:

- Invent a second attachment role or purpose field
- Generate screenshots or crawl URLs
- Copy publication name, website, or logo onto the article
- Require Publication as the only parent
- Ship Featured In, verification, regions, or targets
- Insert Recording rows by hand. Use `record` and `revise`.

Template internals stay in `docs/gem_template/`.
