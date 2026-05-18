# frozen_string_literal: true

require 'test_helper'

module RobotLab
  module Durable
    class ReflectorTest < Minitest::Test
      def setup
        @tmpdir    = Dir.mktmpdir('robot_lab_reflector_test')
        @store     = RobotLab::Durable::Store.new(path: @tmpdir)
        @reflector = RobotLab::Durable::Reflector.new(store: @store, domain: 'newsletter curation')
      end

      def teardown
        FileUtils.remove_entry(@tmpdir)
      end

      def test_promotes_new_learning_to_store
        @reflector.reflect(['User prefers practical tooling examples'])
        results = @store.recall(query: 'practical tooling', domain: 'newsletter curation')
        assert_equal 1, results.size
        assert_equal 'User prefers practical tooling examples', results.first.content
      end

      def test_does_not_duplicate_existing_entry
        @store.record(
          RobotLab::Durable::Entry.new(
            content: 'User prefers practical tooling examples',
            reasoning: 'already stored',
            category: :pattern,
            domain: 'newsletter curation',
            confidence: 0.3,
            use_count: 2,
            created_at: '2026-05-06T12:00:00Z',
            updated_at: '2026-05-06T12:00:00Z'
          )
        )
        @reflector.reflect(['User prefers practical tooling examples'])
        results = @store.recall(query: 'practical tooling', domain: 'newsletter curation')
        assert_equal 1, results.size
      end

      def test_promotes_multiple_learnings
        @reflector.reflect(['First observation', 'Second observation'])
        assert_equal 1, @store.recall(query: 'first',  domain: 'newsletter curation').size
        assert_equal 1, @store.recall(query: 'second', domain: 'newsletter curation').size
      end

      def test_skips_nil_and_empty_learnings
        @reflector.reflect([nil, '', '  '])
        assert_empty @store.recall(query: 'newsletter curation', domain: 'newsletter curation')
      end

      def test_new_entries_start_with_low_confidence
        @reflector.reflect(['Something worth knowing'])
        results = @store.recall(query: 'worth knowing', domain: 'newsletter curation')
        assert_in_delta 0.1, results.first.confidence, 0.001
      end

      def test_existing_entry_confidence_not_overwritten_by_reflect
        @store.record(
          RobotLab::Durable::Entry.new(
            content: 'High confidence pattern',
            reasoning: 'well established',
            category: :pattern,
            domain: 'newsletter curation',
            confidence: 0.8,
            use_count: 7,
            created_at: '2026-05-06T12:00:00Z',
            updated_at: '2026-05-06T12:00:00Z'
          )
        )
        @reflector.reflect(['High confidence pattern'])
        results = @store.recall(query: 'High confidence pattern', domain: 'newsletter curation')
        assert_in_delta 0.8, results.first.confidence, 0.001
      end
    end
  end
end
