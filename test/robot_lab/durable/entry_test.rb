# frozen_string_literal: true

require 'test_helper'

module RobotLab
  module Durable
    class EntryTest < Minitest::Test
      def build_node(overrides = {})
        {
          'id'         => overrides.fetch(:id, 42),
          'content'    => overrides.fetch(:content, 'Always use keyword arguments'),
          'metadata'   => overrides.fetch(:metadata, { 'reasoning' => 'Clearer call sites', 'category' => 'preference' }),
          'created_at' => overrides.fetch(:created_at, '2026-05-06T12:00:00Z')
        }
      end

      def test_from_node_sets_node_id
        entry = Entry.from_node(build_node(id: 7))
        assert_equal 7, entry.node_id
      end

      def test_from_node_sets_content
        entry = Entry.from_node(build_node(content: 'Use frozen string literals'))
        assert_equal 'Use frozen string literals', entry.content
      end

      def test_from_node_sets_reasoning_from_metadata
        entry = Entry.from_node(build_node(metadata: { 'reasoning' => 'Performance', 'category' => 'fact' }))
        assert_equal 'Performance', entry.reasoning
      end

      def test_from_node_sets_category_as_symbol_from_metadata
        entry = Entry.from_node(build_node(metadata: { 'category' => 'pattern' }))
        assert_equal :pattern, entry.category
      end

      def test_from_node_defaults_category_to_fact_when_missing
        entry = Entry.from_node(build_node(metadata: {}))
        assert_equal :fact, entry.category
      end

      def test_from_node_tolerates_nil_metadata
        entry = Entry.from_node(build_node(metadata: nil))
        assert_equal :fact, entry.category
        assert_nil entry.reasoning
      end

      def test_from_node_sets_created_at
        entry = Entry.from_node(build_node(created_at: '2026-01-01T00:00:00Z'))
        assert_equal '2026-01-01T00:00:00Z', entry.created_at
      end

      def test_entry_is_immutable
        entry = Entry.from_node(build_node)
        assert_raises(NoMethodError) { entry.content = 'changed' }
      end

      def test_version_is_defined
        refute_nil RobotLab::Durable::VERSION
      end
    end
  end
end
