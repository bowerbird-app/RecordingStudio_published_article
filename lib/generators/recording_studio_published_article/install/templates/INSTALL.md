RecordingStudioPublishedArticle install complete.

Next steps:

1. Review config/initializers/recording_studio_published_article.rb and set article_parent_types.
2. If you use environment-specific settings, create config/recording_studio_published_article.yml.
3. Add recording_studio_publications and recording_studio_attachable, then install their migrations.
4. Install this gem's migrations with `bin/rails generate recording_studio_published_article:migrations`.
5. Apply the migrations with `bin/rails db:migrate`.
6. Register RecordingStudioPublishedArticle::PublishedArticle, PublicationCatalogue, Publication, and Attachment in RecordingStudio.configure.
7. Mount RecordingStudioAttachable::Engine at /recording_studio_attachable so PDF and screenshot links stay on authorized paths.
8. Run `bin/rails tailwindcss:build` if you use Tailwind CSS.
9. Mount routes are added at the configured mount path. Adjust auth, layout, and current actor integration to match your host app.
10. Keep strict recordable declarations enabled and add `recording_studio_recordable(...)` to every configured recordable before running `RecordingStudio.validate_recordable_declarations!`.
