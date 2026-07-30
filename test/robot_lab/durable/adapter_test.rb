# frozen_string_literal: true

require 'test_helper'

module RobotLab
  module Durable
    # Stand-in for HTM — records calls without hitting PostgreSQL.
    class FakeHTM
      attr_reader :remembered, :last_recall_args

      def initialize(robot_name:)
        @robot_name      = robot_name
        @remembered      = []
        @last_recall_args = nil
        @nodes           = []
      end

      def remember(content, metadata: {})
        @remembered << { content: content, metadata: metadata }
        @remembered.size
      end

      def recall(query, limit: 20, strategy: :hybrid, raw: false, **)
        @last_recall_args = { query: query, limit: limit, strategy: strategy, raw: raw }
        @nodes
      end

      def stub_nodes(nodes)
        @nodes = nodes
      end
    end

    class AdapterTest < Minitest::Test
      def setup
        @fake_htm = FakeHTM.new(robot_name: 'tester')
        @adapter  = Adapter.allocate
        @adapter.instance_variable_set(:@htm, @fake_htm)
      end

      def test_record_calls_htm_remember_with_content
        @adapter.record(content: 'Prefer keyword args', reasoning: 'Clearer', category: 'preference')
        assert_equal 1, @fake_htm.remembered.size
        assert_equal 'Prefer keyword args', @fake_htm.remembered.first[:content]
      end

      def test_record_passes_reasoning_and_category_in_metadata
        @adapter.record(content: 'fact', reasoning: 'because', category: 'fact')
        meta = @fake_htm.remembered.first[:metadata]
        assert_equal 'because', meta['reasoning']
        assert_equal 'fact',    meta['category']
      end

      def test_record_coerces_category_to_string
        @adapter.record(content: 'c', category: :pattern)
        meta = @fake_htm.remembered.first[:metadata]
        assert_equal 'pattern', meta['category']
      end

      def test_record_accepts_nil_reasoning
        @adapter.record(content: 'c', reasoning: nil, category: 'fact')
        meta = @fake_htm.remembered.first[:metadata]
        assert_nil meta['reasoning']
      end

      def test_recall_returns_entries_built_from_nodes
        node = {
          'id'         => 1,
          'content'    => 'Use frozen strings',
          'metadata'   => { 'category' => 'fact', 'reasoning' => 'Speed' },
          'created_at' => '2026-01-01'
        }
        @fake_htm.stub_nodes([node])
        entries = @adapter.recall(query: 'frozen')
        assert_equal 1, entries.size
        assert_kind_of Entry, entries.first
        assert_equal 'Use frozen strings', entries.first.content
        assert_equal :fact, entries.first.category
      end

      def test_recall_passes_strategy_and_limit_to_htm
        @adapter.recall(query: 'test', limit: 5, strategy: :fulltext)
        args = @fake_htm.last_recall_args
        assert_equal 5,         args[:limit]
        assert_equal :fulltext, args[:strategy]
        assert_equal true,      args[:raw]
      end

      def test_recall_defaults_to_hybrid_strategy
        @adapter.recall(query: 'test')
        assert_equal :hybrid, @fake_htm.last_recall_args[:strategy]
      end

      def test_recall_returns_empty_array_when_no_nodes
        entries = @adapter.recall(query: 'nothing')
        assert_empty entries
      end

      def test_htm_accessor_exposes_underlying_htm_instance
        assert_same @fake_htm, @adapter.htm
      end
    end
  end
end
