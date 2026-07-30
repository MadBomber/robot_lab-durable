# frozen_string_literal: true

require_relative 'durable/version'
require_relative 'durable/entry'
require_relative 'durable/adapter'

# Minimal error stub so the adapter layer works without robot_lab loaded.
# When robot_lab is present its own RobotLab::Error takes precedence.
module RobotLab
  Error = StandardError unless defined?(Error)
end

if defined?(RobotLab::Hook)
  require_relative 'durable/hook'
end

if defined?(RobotLab::Tool)
  require_relative 'recall_knowledge'
  require_relative 'record_knowledge'
end

if defined?(RobotLab) && RobotLab.respond_to?(:register_extension)
  RobotLab.register_extension(:durable, RobotLab::Durable)
end
