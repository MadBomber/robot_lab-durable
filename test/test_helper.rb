# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'robot_lab'
require 'robot_lab/durable'

require 'fileutils'
require 'tmpdir'

require 'minitest/autorun'
require 'minitest/pride'
