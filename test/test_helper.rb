# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

# Load the pure storage layer without robot_lab to avoid conflicts while
# robot_lab still ships its own copy of the durable files. Once robot_lab
# drops those files and adds robot_lab-durable as a dependency, switch to:
#   require "robot_lab/durable"
module RobotLab
  Error = StandardError unless defined?(Error)
end

require 'robot_lab/durable/version'
require 'robot_lab/durable/entry'
require 'robot_lab/durable/store'
require 'robot_lab/durable/reflector'

require 'fileutils'
require 'tmpdir'

require 'minitest/autorun'
require 'minitest/pride'
