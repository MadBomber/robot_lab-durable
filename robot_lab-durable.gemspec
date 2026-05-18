# frozen_string_literal: true

require_relative 'lib/robot_lab/durable/version'

Gem::Specification.new do |spec|
  spec.name     = 'robot_lab-durable'
  spec.version  = RobotLab::Durable::VERSION
  spec.authors  = ['Dewayne VanHoozer']
  spec.email    = ['dvanhoozer@gmail.com']

  spec.summary     = 'Cross-session durable learning for RobotLab agents'
  spec.description = 'Provides RobotLab::Durable — a YAML-backed knowledge store that lets ' \
                     'robot_lab agents accumulate and recall observations across sessions. ' \
                     'Includes Entry (immutable value object with confidence scoring), Store ' \
                     '(file-locked per-domain persistence), Reflector (end-of-session promoter), ' \
                     'and the Learning mixin with RecallKnowledge/RecordKnowledge tools that ' \
                     'integrate directly into Robot when robot_lab is present.'
  spec.homepage = 'https://github.com/MadBomber/robot_lab-durable'
  spec.license  = 'MIT'

  spec.required_ruby_version = '>= 3.2.0'

  spec.metadata['homepage_uri']    = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri']   = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore test/ sig/])
    end
  end

  spec.require_paths = ['lib']

  # robot_lab is required at runtime for the Learning mixin, RecallKnowledge,
  # and RecordKnowledge tools. The pure storage layer (Entry, Store, Reflector)
  # works standalone when robot_lab is not loaded.
  spec.add_dependency 'robot_lab'
end
