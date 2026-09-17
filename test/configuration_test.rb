# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    @original_configuration = RecordingStudioPublishedArticle.instance_variable_get(:@configuration)
    @configuration = RecordingStudioPublishedArticle::Configuration.new
    RecordingStudioPublishedArticle.instance_variable_set(:@configuration, @configuration)
  end

  def teardown
    RecordingStudioPublishedArticle.instance_variable_set(:@configuration, @original_configuration)
  end

  def test_defaults_to_no_article_parents
    assert_equal [], @configuration.article_parent_types
    assert_equal [], RecordingStudioPublishedArticle.article_parent_types
  end

  def test_merge_updates_article_parent_types
    @configuration.merge!(article_parent_types: %w[Workspace Folder])

    assert_equal %w[Workspace Folder], @configuration.article_parent_types
  end

  def test_merge_ignores_unknown_keys
    @configuration.merge!(unknown_key: "ignored", article_parent_types: %w[Folder])

    refute_respond_to @configuration, :unknown_key
    assert_equal %w[Folder], @configuration.article_parent_types
  end

  def test_merge_with_non_enumerable_is_noop
    original = @configuration.to_h

    @configuration.merge!(nil)

    assert_equal original[:article_parent_types], @configuration.article_parent_types
  end

  def test_merge_accepts_string_keys
    @configuration.merge!("article_parent_types" => %w[Folder])

    assert_equal %w[Folder], @configuration.article_parent_types
  end

  def test_to_h_reports_registered_hook_counts
    @configuration.hooks.before_initialize { nil }
    @configuration.hooks.before_initialize { nil }
    @configuration.hooks.after_service { nil }

    result = @configuration.to_h

    assert_equal [], result.fetch(:article_parent_types)
    assert_equal 2, result.fetch(:hooks_registered).fetch(:before_initialize)
    assert_equal 1, result.fetch(:hooks_registered).fetch(:after_service)
  end

  def test_configure_without_block_is_safe
    RecordingStudioPublishedArticle.configure

    assert_kind_of RecordingStudioPublishedArticle::Configuration, RecordingStudioPublishedArticle.configuration
  end

  def test_article_parent_types_setter_stores_strings
    RecordingStudioPublishedArticle.article_parent_types = %i[Workspace Folder]

    assert_equal %w[Workspace Folder], RecordingStudioPublishedArticle.article_parent_types
  end

  def test_pdf_and_screenshot_helpers_are_empty_without_attachable_methods
    recording = Object.new

    assert_equal [], RecordingStudioPublishedArticle.pdf_attachments(recording)
    assert_equal [], RecordingStudioPublishedArticle.screenshot_attachments(recording)
  end

  def test_pdf_attachments_keeps_only_application_pdf_files
    pdf = Object.new
    pdf.define_singleton_method(:recordable) { Struct.new(:content_type).new("application/pdf") }
    other = Object.new
    other.define_singleton_method(:recordable) { Struct.new(:content_type).new("text/plain") }
    recording = Object.new
    recording.define_singleton_method(:files) { |**| [pdf, other] }

    assert_equal [pdf], RecordingStudioPublishedArticle.pdf_attachments(recording)
  end

  def test_screenshot_attachments_returns_images
    image = Object.new
    recording = Object.new
    recording.define_singleton_method(:images) { |**| [image] }

    assert_equal [image], RecordingStudioPublishedArticle.screenshot_attachments(recording)
  end

  def test_publication_recording_for_blank_or_unrelated_is_nil
    assert_nil RecordingStudioPublishedArticle.publication_recording_for(nil)
    assert_nil RecordingStudioPublishedArticle.publication_recording_for("")
    assert_nil RecordingStudioPublishedArticle.publication_recording_for(Object.new)
  end

  def test_publication_recording_for_accepts_a_publication_recording_and_rejects_other_recordings
    publication_recording = Object.new
    publication_recording.define_singleton_method(:recordable_type) { "RecordingStudioPublications::Publication" }
    other = Object.new
    other.define_singleton_method(:recordable_type) { "Workspace" }

    assert_equal publication_recording, RecordingStudioPublishedArticle.publication_recording_for(publication_recording)
    assert_nil RecordingStudioPublishedArticle.publication_recording_for(other)
  end
end
