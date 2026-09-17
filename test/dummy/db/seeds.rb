SEED_PNG_PATH = Rails.root.join("db/seed_assets/screenshot.png") unless defined?(SEED_PNG_PATH)
SEED_PDF_PATH = Rails.root.join("db/seed_assets/article.pdf") unless defined?(SEED_PDF_PATH)

find_or_record_child = lambda do |recordable, root_recording, parent_recording|
  RecordingStudio::Recording.find_by(
    root_recording: root_recording,
    parent_recording: parent_recording,
    recordable: recordable,
    trashed_at: nil
  ) || RecordingStudio.record!(
    action: "created",
    recordable: recordable,
    root_recording: root_recording,
    parent_recording: parent_recording
  ).recording
end

bootstrap_owner_access = lambda do |actor, recording|
  result = RecordingStudioAccessible.bootstrap_owner_access!(recording: recording, actor: actor)
  raise result.error if result.failure?
end

find_article_recording = lambda do |title, parent_recording|
  RecordingStudio::Recording.where(
    recordable_type: RecordingStudioPublishedArticle::PublishedArticle.name,
    parent_recording: parent_recording,
    trashed_at: nil
  ).detect { |recording| recording.recordable.title == title }
end

record_article = lambda do |parent_recording, attrs, actor:|
  existing = find_article_recording.call(attrs.fetch(:title), parent_recording)
  return existing if existing

  root = parent_recording.root_recording || parent_recording
  root.record(
    RecordingStudioPublishedArticle::PublishedArticle,
    actor: actor,
    parent_recording: parent_recording
  ) do |article|
    article.title = attrs.fetch(:title)
    article.url = attrs[:url]
    article.published_at = attrs[:published_at]
    article.author = attrs[:author]
    article.excerpt = attrs[:excerpt]
    article.publication_recording_id = attrs[:publication_recording_id]
  end
end

attachment_filenames = lambda do |article_recording|
  RecordingStudio::Recording.where(
    parent_recording: article_recording,
    recordable_type: RecordingStudioAttachable::Attachment.name,
    trashed_at: nil
  ).filter_map { |recording| recording.recordable&.original_filename }
end

ensure_attachment = lambda do |article_recording, filename:, content_type:, path:, actor:|
  return if attachment_filenames.call(article_recording).include?(filename)

  File.open(path, "rb") do |io|
    article_recording.import_attachment(
      io: io,
      filename: filename,
      content_type: content_type,
      actor: actor,
      identify: false
    )
  end
end

publication_recording_for_key = lambda do |name:, key:, kind:, website:, actor:|
  existing = RecordingStudioPublications::Publication.find_by(key: key)
  return RecordingStudioPublications.recording_for(existing) if existing

  RecordingStudioPublications.record_publication!(
    { name: name, key: key, kind: kind, website: website },
    actor: actor
  )
end

user = User.find_or_create_by!(email: "admin@admin.com") do |u|
  u.password = "Password"
  u.password_confirmation = "Password"
end

workspace = Workspace.find_or_create_by!(name: "Studio Workspace")
accessible_workspace = Workspace.find_or_create_by!(name: "Client Workspace")
private_workspace = Workspace.find_or_create_by!(name: "Private Workspace")
folder = Folder.find_or_create_by!(name: "Product Docs")
page = Page.find_or_create_by!(title: "Getting Started")

previous_actor = Current.actor
Current.actor = user

begin
  root_recording = RecordingStudio.root_recording_for(workspace)
  accessible_root_recording = RecordingStudio.root_recording_for(accessible_workspace)
  private_root_recording = RecordingStudio.root_recording_for(private_workspace)

  bootstrap_owner_access.call(user, root_recording)

  folder_recording = find_or_record_child.call(folder, root_recording, root_recording)
  find_or_record_child.call(page, root_recording, folder_recording)

  atlantic = publication_recording_for_key.call(
    name: "The Atlantic",
    key: "the-atlantic",
    kind: "magazine",
    website: "https://www.theatlantic.com",
    actor: user
  )
  guardian = publication_recording_for_key.call(
    name: "The Guardian",
    key: "the-guardian",
    kind: "newspaper",
    website: "https://www.theguardian.com",
    actor: user
  )

  png = { path: SEED_PNG_PATH, content_type: "image/png" }
  pdf = { path: SEED_PDF_PATH, content_type: "application/pdf" }

  articles = [
    {
      parent: root_recording,
      attrs: {
        title: "A letter without a copy",
        url: "https://example.com/letter-without-copy",
        published_at: Time.utc(2024, 1, 15),
        author: "Bea Line",
        excerpt: "URL only.",
        publication_recording_id: guardian.id
      },
      attachments: []
    },
    {
      parent: root_recording,
      attrs: {
        title: "PDF only field notes",
        published_at: Time.utc(2023, 9, 4),
        author: "Ada Staff",
        excerpt: "A PDF with no public URL.",
        publication_recording_id: atlantic.id
      },
      attachments: [pdf.merge(filename: "field-notes.pdf")]
    },
    {
      parent: root_recording,
      attrs: {
        title: "Screenshot only gallery",
        published_at: Time.utc(2024, 2, 20),
        author: "Ada Staff",
        excerpt: "A screenshot with no public URL.",
        publication_recording_id: atlantic.id
      },
      attachments: [png.merge(filename: "gallery.png")]
    },
    {
      parent: root_recording,
      attrs: {
        title: "The Quiet Crop",
        url: "https://example.com/quiet-crop",
        published_at: Time.utc(2024, 3, 12),
        author: "Ada Staff",
        excerpt: "A short pull-quote from the field.",
        publication_recording_id: atlantic.id
      },
      attachments: [pdf.merge(filename: "quiet-crop.pdf")]
    },
    {
      parent: root_recording,
      attrs: {
        title: "URL and screenshot together",
        url: "https://example.com/url-and-screenshot",
        published_at: Time.utc(2024, 4, 8),
        author: "Bea Line",
        excerpt: "A link and a screenshot.",
        publication_recording_id: guardian.id
      },
      attachments: [png.merge(filename: "url-and-screenshot.png")]
    },
    {
      parent: root_recording,
      attrs: {
        title: "Full set from the field",
        url: "https://example.com/full-set",
        published_at: Time.utc(2024, 5, 19),
        author: "Ada Staff",
        excerpt: "URL, PDF, and screenshot.",
        publication_recording_id: atlantic.id
      },
      attachments: [
        pdf.merge(filename: "full-set.pdf"),
        png.merge(filename: "full-set.png")
      ]
    },
    {
      parent: folder_recording,
      attrs: {
        title: "Screens from the harvest",
        url: "https://example.com/harvest-screens",
        published_at: Time.utc(2024, 6, 2),
        author: "Ada Staff",
        excerpt: "Kept with Product Docs.",
        publication_recording_id: atlantic.id
      },
      attachments: [png.merge(filename: "harvest.png")]
    },
    {
      parent: atlantic,
      attrs: {
        title: "Archive copy under The Atlantic",
        published_at: Time.utc(2023, 11, 8),
        author: "Ada Staff",
        excerpt: "Kept with the publication for archive context.",
        publication_recording_id: atlantic.id
      },
      attachments: []
    }
  ]

  articles.each do |entry|
    article_recording = record_article.call(entry[:parent], entry[:attrs], actor: user)
    entry[:attachments].each do |attachment|
      ensure_attachment.call(
        article_recording,
        filename: attachment[:filename],
        content_type: attachment[:content_type],
        path: attachment[:path],
        actor: user
      )
    end
  end
ensure
  Current.actor = previous_actor
end

puts "Seeded: admin@admin.com / Password"
puts "Seeded: Workspace '#{workspace.name}' with root recording ##{root_recording.id}"
puts "Seeded: Workspace '#{accessible_workspace.name}' with root recording ##{accessible_root_recording.id}"
puts "Seeded: Workspace '#{private_workspace.name}' with root recording ##{private_root_recording.id}"
puts "Seeded: Folder '#{folder.name}' and page '#{page.title}'"
puts "Seeded: Publications The Atlantic and The Guardian with article copies"
