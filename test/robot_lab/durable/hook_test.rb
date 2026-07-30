# frozen_string_literal: true

require 'test_helper'

module RobotLab
  module Durable
    # Lightweight adapter double — no PostgreSQL required.
    class FakeAdapter
      attr_reader :records, :recalls

      def initialize
        @records = []
        @recalls = []
      end

      def record(content:, reasoning: nil, category: 'fact')
        @records << { content: content, reasoning: reasoning, category: category.to_s }
        @records.size
      end

      def recall(query:, **)
        @recalls << query
        []
      end
    end

    class HookTest < Minitest::Test
      def setup
        Thread.current[:robot_lab_durable_adapter] = nil
        @robot        = build_robot
        @fake_adapter = FakeAdapter.new
      end

      def teardown
        Thread.current[:robot_lab_durable_adapter] = nil
      end

      # ── current_adapter ──────────────────────────────────────────────────────

      def test_current_adapter_is_nil_by_default
        assert_nil Hook.current_adapter
      end

      def test_current_adapter_returns_adapter_when_set
        Thread.current[:robot_lab_durable_adapter] = @fake_adapter
        assert_same @fake_adapter, Hook.current_adapter
      end

      # ── around_run ───────────────────────────────────────────────────────────

      def test_around_run_sets_adapter_during_block
        adapter_during_run = nil
        run_with_fake_adapter { adapter_during_run = Hook.current_adapter }
        refute_nil adapter_during_run
        assert_same @fake_adapter, adapter_during_run
      end

      def test_around_run_clears_adapter_after_block
        run_with_fake_adapter { nil }
        assert_nil Hook.current_adapter
      end

      def test_around_run_clears_adapter_when_block_raises
        assert_raises(RuntimeError) { run_with_fake_adapter { raise 'boom' } }
        assert_nil Hook.current_adapter
      end

      # ── on_learn ─────────────────────────────────────────────────────────────

      def test_on_learn_records_when_stored_and_adapter_active
        Thread.current[:robot_lab_durable_adapter] = @fake_adapter
        Hook.on_learn(learn_ctx(text: 'Always freeze string literals', stored: true))
        assert_equal 1, @fake_adapter.records.size
        assert_equal 'Always freeze string literals', @fake_adapter.records.first[:content]
        assert_equal 'observation', @fake_adapter.records.first[:category]
      end

      def test_on_learn_skips_when_stored_false
        Thread.current[:robot_lab_durable_adapter] = @fake_adapter
        Hook.on_learn(learn_ctx(text: 'duplicate', stored: false))
        assert_empty @fake_adapter.records
      end

      def test_on_learn_skips_when_no_adapter_active
        Hook.on_learn(learn_ctx(text: 'orphan', stored: true))
        # No adapter set — should be a no-op, not raise
      end

      # ── integration: on_learn inside around_run ───────────────────────────────

      def test_learning_during_run_is_persisted
        run_with_fake_adapter do
          Hook.on_learn(learn_ctx(text: 'blanch before freezing', stored: true))
        end
        assert_equal 1, @fake_adapter.records.size
        assert_equal 'blanch before freezing', @fake_adapter.records.first[:content]
      end

      private

      def build_robot(name: 'test_robot')
        Struct.new(:learnings, :name) do
          def initialize(name)
            super([], name)
          end

          def learn(text)
            learnings << text unless learnings.include?(text)
            self
          end
        end.new(name)
      end

      def learn_ctx(text:, stored:)
        ctx = RobotLab::LearnHookContext.new(
          robot:            @robot,
          text:             text,
          learnings_before: @robot.learnings.dup
        )
        ctx.stored = stored
        ctx
      end

      def run_with_fake_adapter(&)
        fake = @fake_adapter
        Adapter.stub(:new, fake) do
          ctx = RobotLab::RunHookContext.new(robot: @robot, request: 'test')
          Hook.around_run(ctx, &)
        end
      end
    end
  end
end
