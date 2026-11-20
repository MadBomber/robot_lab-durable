# frozen_string_literal: true

require 'test_helper'

module RobotLab
  module Durable
    class ToolsTest < Minitest::Test
      # Adapter double — no PostgreSQL required.
      class RecordingAdapter
        attr_reader :records, :queries
        attr_accessor :entries

        def initialize
          @records = []
          @queries = []
          @entries = []
        end

        def record(content:, reasoning: nil, category: 'fact')
          @records << { content: content, reasoning: reasoning, category: category.to_s }
          @records.size
        end

        def recall(query:, **)
          @queries << query
          @entries
        end
      end

      Learner = Struct.new(:learnings) do
        def learn(text)
          learnings << text
          self
        end
      end

      def setup
        clear_session
        @adapter = RecordingAdapter.new
        @robot   = Learner.new([])
      end

      def teardown = clear_session

      # ── RecordKnowledge ──────────────────────────────────────────────────────

      def test_record_without_durable_session_writes_nothing
        result = RecordKnowledge.new(robot: @robot).execute(content: 'c', reasoning: 'r', category: 'fact')
        assert_equal 'No durable session active on this robot.', result
        assert_empty @adapter.records
        assert_empty @robot.learnings
      end

      def test_record_with_bound_robot_records_and_learns
        start_session(robot: nil)
        result = RecordKnowledge.new(robot: @robot).execute(content: 'Risk averse', reasoning: 'said so',
                                                            category: 'preference')
        assert_equal 'Recorded: Risk averse', result
        assert_equal [{ content: 'Risk averse', reasoning: 'said so', category: 'preference' }], @adapter.records
        assert_equal ['Risk averse'], @robot.learnings
      end

      # Regression: attached as a bare class the tool has no robot; it used to
      # write to HTM and then raise NoMethodError on nil.learn.
      def test_record_without_bound_robot_learns_on_session_robot
        start_session(robot: @robot)
        result = RecordKnowledge.new.execute(content: 'Risk averse', reasoning: 'said so', category: 'preference')
        assert_equal 'Recorded: Risk averse', result
        assert_equal 1, @adapter.records.size
        assert_equal ['Risk averse'], @robot.learnings
      end

      def test_record_without_any_robot_still_records_and_succeeds
        start_session(robot: nil)
        result = RecordKnowledge.new.execute(content: 'c', reasoning: 'r', category: 'fact')
        assert_equal 'Recorded: c', result
        assert_equal 1, @adapter.records.size
      end

      def test_learner_prefers_the_tools_own_robot
        other = Learner.new([])
        start_session(robot: other)
        assert_same @robot, RecordKnowledge.new(robot: @robot).learner
        assert_same other,  RecordKnowledge.new.learner
      end

      def test_learner_is_nil_outside_a_session_without_robot
        assert_nil RecordKnowledge.new.learner
      end

      # ── RecallKnowledge ──────────────────────────────────────────────────────

      def test_recall_without_durable_session
        assert_equal 'No durable session active on this robot.', RecallKnowledge.new.execute(query: 'q')
      end

      def test_recall_with_no_matches
        start_session(robot: @robot)
        assert_equal 'No relevant past knowledge found for: q. When in doubt, skip.',
                     RecallKnowledge.new.execute(query: 'q')
        assert_equal ['q'], @adapter.queries
      end

      def test_recall_formats_entries_with_category_and_reasoning
        start_session(robot: @robot)
        @adapter.entries = [
          entry(content: 'Prefers index funds', reasoning: 'stated twice', category: :preference),
          entry(content: 'Asked about bonds',   reasoning: nil,            category: :observation)
        ]
        expected = "Relevant past knowledge:\n" \
                   "[preference] Prefers index funds — stated twice\n" \
                   '[observation] Asked about bonds'
        assert_equal expected, RecallKnowledge.new.execute(query: 'funds')
      end

      def test_format_entry_omits_blank_reasoning
        tool = RecallKnowledge.new
        assert_equal '[fact] c',     tool.format_entry(entry(content: 'c', reasoning: '', category: :fact))
        assert_equal '[fact] c — r', tool.format_entry(entry(content: 'c', reasoning: 'r', category: :fact))
      end

      private

      def entry(content:, reasoning:, category:)
        Entry.new(node_id: 1, content: content, reasoning: reasoning, category: category, created_at: Time.utc(2026, 1, 1))
      end

      def start_session(robot:)
        Thread.current[:robot_lab_durable_adapter] = @adapter
        Thread.current[:robot_lab_durable_robot]   = robot
      end

      def clear_session
        Thread.current[:robot_lab_durable_adapter] = nil
        Thread.current[:robot_lab_durable_robot]   = nil
      end
    end
  end
end
