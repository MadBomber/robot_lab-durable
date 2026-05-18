# frozen_string_literal: true

require 'test_helper'

module RobotLab
  module Durable
    class VersionTest < Minitest::Test
      def test_version_is_defined
        refute_nil RobotLab::Durable::VERSION
      end
    end
  end
end
