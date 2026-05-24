# frozen_string_literal: true

require_relative 'lib/robot_lab/durable/version'

Gem::Specification.new do |spec|
  spec.name     = 'robot_lab-durable'
  spec.version  = RobotLab::Durable::VERSION
  spec.authors  = ['Dewayne VanHoozer']
  spec.email    = ['dvanhoozer@gmail.com']

  spec.summary     = 'HTM-backed long-term memory for RobotLab agents'
  spec.description = 'Provides RobotLab::Durable — an adapter between robot_lab and the HTM gem ' \
                     '(Hierarchical Temporal Memory). Replaces the former YAML store with ' \
                     'PostgreSQL-backed long-term memory featuring vector embeddings, hybrid ' \
                     'semantic search, hierarchical tagging, and multi-robot federation. ' \
                     'Includes RecallKnowledge and RecordKnowledge tools that integrate ' \
                     'directly into Robot when robot_lab is present.'
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

  spec.add_dependency 'robot_lab', '~> 0.2.0'
  spec.add_dependency 'htm'
end
