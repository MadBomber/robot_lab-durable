# frozen_string_literal: true

require 'test_helper'

module RobotLab
  module Durable
    class VersionTest < Minitest::Test
      def test_version_is_defined
        refute_nil RobotLab::Durable::VERSION
      end

      def test_entry_is_accessible
        assert_equal RobotLab::Durable::Entry, RobotLab::Durable::Entry
      end

      def test_adapter_is_accessible
        assert_equal RobotLab::Durable::Adapter, RobotLab::Durable::Adapter
      end
    end
  end
end
