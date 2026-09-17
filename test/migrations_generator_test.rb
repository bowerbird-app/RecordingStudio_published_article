# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"
require "generators/recording_studio_published_article/migrations/migrations_generator"

class MigrationsGeneratorTest < Minitest::Test
  def test_copy_migrations_installs_the_articles_table
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "db/migrate"))
      generator = RecordingStudioPublishedArticle::Generators::MigrationsGenerator.new(
        [],
        { skip_existing: true },
        destination_root: dir
      )

      generator.stub(:say, nil) do
        generator.stub(:sleep, nil) do
          generator.copy_migrations
        end
      end

      files = Dir.glob(File.join(dir, "db/migrate", "*_create_recording_studio_published_article_articles.rb"))
      assert_equal 1, files.size
      contents = File.read(files.first)
      assert_includes contents, "create_table :recording_studio_published_article_articles"
      assert_includes contents, "t.string :title, null: false"
      assert_includes contents, "t.uuid :publication_recording_id"
      refute_includes contents, "updated_at"
      refute_includes contents, "create_recording_studio_published_article_pages"
    end
  end

  def test_copy_migrations_skips_existing_articles_migration
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "db/migrate"))
      File.write(
        File.join(dir, "db/migrate", "20200101000000_create_recording_studio_published_article_articles.rb"),
        "existing"
      )
      generator = RecordingStudioPublishedArticle::Generators::MigrationsGenerator.new(
        [],
        { skip_existing: true },
        destination_root: dir
      )
      messages = []

      generator.stub(:say, ->(message, color = nil) { messages << [message, color] }) do
        generator.stub(:sleep, nil) do
          generator.copy_migrations
        end
      end

      assert(messages.any? { |message, _color| message.to_s.include?("already exists") })
      files = Dir.glob(File.join(dir, "db/migrate", "*_create_recording_studio_published_article_articles.rb"))
      assert_equal 1, files.size
      assert_equal "existing", File.read(files.first)
    end
  end
end
