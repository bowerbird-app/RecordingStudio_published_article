# frozen_string_literal: true

require_relative "lib/recording_studio_published_article/version"

Gem::Specification.new do |spec|
  spec.name        = "recording_studio_published_article"
  spec.version     = RecordingStudioPublishedArticle::VERSION
  spec.authors     = ["Bowerbird"]
  spec.homepage    = "https://github.com/bowerbird-app/RecordingStudio_published_article"
  spec.summary     = "Reusable Published Article recordable for Recording Studio"
  spec.description = "A Recording Studio addon that stores published articles as nested recordables, " \
                     "with optional publication lookup, PDF copies, and screenshot copies via Attachable."
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/bowerbird-app/RecordingStudio_published_article"
  spec.metadata["changelog_uri"] = "https://github.com/bowerbird-app/RecordingStudio_published_article/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"].reject do |path|
      path == ".cursor" || path.start_with?(".cursor/")
    end
  end

  spec.add_dependency "flat_pack", ">= 0.1.143"
  spec.add_dependency "rails", "~> 8.1.0"
  spec.add_dependency "recording_studio", "~> 4.2"
  spec.add_dependency "recording_studio_attachable", "~> 0.5"
  spec.add_dependency "recording_studio_publications", "~> 0.2"
end
