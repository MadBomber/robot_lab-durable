# frozen_string_literal: true

require_relative 'durable/version'
require_relative 'durable/entry'
require_relative 'durable/store'
require_relative 'durable/reflector'
require_relative 'durable/learning'

# Minimal error stub so the storage layer works without robot_lab loaded.
# When robot_lab is present its own RobotLab::Error takes precedence.
module RobotLab
  Error = StandardError unless defined?(Error)
end

# When robot_lab is loaded, register the knowledge tools and hook the
# Learning mixin into Robot so `learn: true` works in the constructor.
if defined?(RobotLab::Tool)
  require_relative 'recall_knowledge'
  require_relative 'record_knowledge'
end

RobotLab::Robot.include(RobotLab::Durable::Learning) if defined?(RobotLab::Robot)

if defined?(RobotLab) && RobotLab.respond_to?(:register_extension)
  RobotLab.register_extension(:durable, RobotLab::Durable)
end
