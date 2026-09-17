# frozen_string_literal: true

require "view_component"
require "flat_pack"

module RecordingStudioPublishedArticle
  class Engine < ::Rails::Engine
    isolate_namespace RecordingStudioPublishedArticle

    class << self
      def apply_model_extensions(target)
        apply_extensions(target, extensions_for(:model, extension_keys_for(target)))
      end

      def apply_controller_extensions(target)
        apply_extensions(target, extensions_for(:controller, extension_keys_for(target)))
      end

      def load_app_configuration(app)
        merge_yaml_configuration(app)
        merge_x_configuration(app)
        RecordingStudioPublishedArticle.configuration.hooks.run(
          :on_configuration,
          RecordingStudioPublishedArticle.configuration
        )
      end

      private

      def extensions_for(kind, names)
        hooks = RecordingStudioPublishedArticle.configuration.hooks
        Array(names).flat_map do |name|
          if kind == :model
            hooks.model_extensions_for(name)
          else
            hooks.controller_extensions_for(name)
          end
        end
      end

      def apply_extensions(target, extensions)
        return unless target

        applied = target.instance_variable_get(:@recording_studio_published_article_applied_extensions) || identity_hash

        extensions.flatten.compact.each do |extension|
          next if applied[extension]

          target.class_eval(&extension)
          applied[extension] = true
        end

        target.instance_variable_set(:@recording_studio_published_article_applied_extensions, applied)
      end

      def extension_keys_for(target)
        names = [target.name, target.name&.demodulize].compact.uniq
        names.map(&:to_sym)
      end

      def identity_hash
        {}.compare_by_identity
      end

      def merge_yaml_configuration(app)
        return unless app.respond_to?(:config_for)

        yaml = app.config_for(:recording_studio_published_article)
        RecordingStudioPublishedArticle.configuration.merge!(yaml) if yaml.respond_to?(:each)
      rescue StandardError
        nil
      end

      def merge_x_configuration(app) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
        return unless app.config.respond_to?(:x) && app.config.x.respond_to?(:recording_studio_published_article)

        xcfg = app.config.x.recording_studio_published_article
        if xcfg.respond_to?(:to_h)
          RecordingStudioPublishedArticle.configuration.merge!(xcfg.to_h)
          return
        end

        hash = {}
        xcfg.each_pair { |k, v| hash[k] = v } if xcfg.respond_to?(:each_pair)
        RecordingStudioPublishedArticle.configuration.merge!(hash) if hash.any?
      rescue StandardError
        nil
      end
    end

    initializer "recording_studio_published_article.before_initialize",
                before: "recording_studio_published_article.load_config" do |_app|
      RecordingStudioPublishedArticle.configuration.hooks.run(:before_initialize, self)
    end

    initializer "recording_studio_published_article.load_config" do |app|
      RecordingStudioPublishedArticle::Engine.load_app_configuration(app)
    end

    initializer "recording_studio_published_article.after_initialize",
                after: "recording_studio_published_article.load_config" do |_app|
      RecordingStudioPublishedArticle.configuration.hooks.run(:after_initialize, self)
    end

    initializer "recording_studio_published_article.apply_model_extensions" do
      config.to_prepare do
        next unless defined?(ActiveRecord::Base)

        ActiveRecord::Base.descendants.each do |model|
          next if model.abstract_class?

          RecordingStudioPublishedArticle::Engine.apply_model_extensions(model)
        end
      end
    end

    initializer "recording_studio_published_article.apply_controller_extensions" do
      config.to_prepare do
        next unless defined?(ActionController::Base)

        ActionController::Base.descendants.each do |controller|
          RecordingStudioPublishedArticle::Engine.apply_controller_extensions(controller)
        end
      end
    end

    initializer "recording_studio_published_article.declare_article" do
      config.to_prepare do
        RecordingStudioPublishedArticle.redeclare_published_article!
      end
    end
  end
end
