# frozen_string_literal: true

require "test_helper"

class RobotLab::Durable::VersionTest < Minitest::Test
  def test_version_is_defined
    refute_nil RobotLab::Durable::VERSION
  end
end
