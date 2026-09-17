# frozen_string_literal: true

module RecordingStudioPublishedArticle
  class ApplicationController < (defined?(::ApplicationController) ? ::ApplicationController : ActionController::Base)
    include RecordingStudio::UsesDefaultLayout if defined?(RecordingStudio::UsesDefaultLayout)
    include Devise::Controllers::Helpers if defined?(Devise::Controllers::Helpers)
    if defined?(RecordingStudio::RootSwitchable::ControllerSupport)
      include RecordingStudio::RootSwitchable::ControllerSupport
    end

    protect_from_forgery with: :exception
    layout "recording_studio/default_layout"

    helper ::RecordingStudio::LayoutHelper if defined?(::RecordingStudio::LayoutHelper)
    helper ::RecordingStudioAttachable::Engine.helpers if defined?(::RecordingStudioAttachable::Engine)
    helper ArticlesHelper

    before_action :authenticate_published_article_actor!
    before_action :set_current_actor

    private

    def authenticate_published_article_actor!
      return if performed?
      return send(:authenticate_user!) if respond_to?(:authenticate_user!, true)

      head :unauthorized
    end

    def set_current_actor
      return unless defined?(Current) && Current.respond_to?(:actor=)

      Current.actor = published_article_actor
    end

    def published_article_actor
      return current_user if respond_to?(:current_user) && current_user.present?
      return Current.actor if defined?(Current) && Current.respond_to?(:actor) && Current.actor.present?

      nil
    end

    def authorize_view!(recording)
      actor = published_article_actor
      unless actor
        head :unauthorized
        return
      end

      return if view_allowed?(actor, recording)

      head :forbidden
    end

    def view_allowed?(actor, recording)
      return false if recording.blank?
      return true if recording.respond_to?(:shared_root_tree?) && recording.shared_root_tree?
      return true unless defined?(RecordingStudioAccessible)

      RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: :view)
    end
  end
end
