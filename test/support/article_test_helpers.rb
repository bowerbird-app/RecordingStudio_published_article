# frozen_string_literal: true

require "base64"
require "securerandom"

module ArticleTestHelpers
  ONE_PIXEL_PNG = Base64.decode64(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
  ).freeze
  MINIMAL_PDF = [
    "%PDF-1.1\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n",
    "2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n",
    "3 0 obj<</Type/Page/MediaBox[0 0 3 3]>>endobj\n",
    "trailer<</Size 4/Root 1 0 R>>\n%%EOF\n"
  ].join.freeze

  def unique_name(prefix)
    "#{prefix} #{SecureRandom.hex(4)}"
  end

  def create_actor(email_prefix: "article")
    User.create!(
      email: "#{email_prefix}-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
  end

  def bootstrap_owner_access!(actor, recording)
    result = RecordingStudioAccessible.bootstrap_owner_access!(recording: recording, actor: actor)
    return result.value if result.success?

    raise result.error
  end

  def workspace_root_for(name, actor:)
    workspace = Workspace.create!(name: name)
    root = RecordingStudio.root_recording_for(workspace)
    bootstrap_owner_access!(actor, root)
    root
  end

  def record_folder(root_recording, name)
    RecordingStudio.record!(
      action: "created",
      recordable: Folder.new(name: name),
      root_recording: root_recording,
      parent_recording: root_recording
    ).recording
  end

  def record_page(root_recording, parent_recording, title)
    RecordingStudio.record!(
      action: "created",
      recordable: Page.new(title: title),
      root_recording: root_recording,
      parent_recording: parent_recording
    ).recording
  end

  def record_article!(parent_recording, attrs, actor:)
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

  def attach_copy!(article_recording, filename:, content_type:, io:, actor:)
    article_recording.import_attachment(
      io: StringIO.new(io),
      filename: filename,
      content_type: content_type,
      actor: actor,
      identify: false
    )
  end

  def record_publication!(attrs, actor:)
    RecordingStudioPublications.record_publication!(attrs, actor: actor)
  end
end
