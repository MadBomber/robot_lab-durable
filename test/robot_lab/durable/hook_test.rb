# frozen_string_literal: true

require 'test_helper'

module RobotLab
  module Durable
    class HookTest < Minitest::Test
      def setup
        @store_dir = Dir.mktmpdir('durable_hook_test')
        @store     = Store.new(path: @store_dir)
        @robot     = build_robot
        Thread.current[:robot_lab_durable_session]      = nil
        Thread.current[:robot_lab_durable_skip_persist] = nil
      end

      def teardown
        Thread.current[:robot_lab_durable_session]      = nil
        Thread.current[:robot_lab_durable_skip_persist] = nil
        FileUtils.rm_rf(@store_dir)
      end

      # ── current_session ──────────────────────────────────────────────────────

      def test_current_session_is_nil_by_default
        assert_nil Hook.current_session
      end

      def test_current_session_returns_session_when_set
        Thread.current[:robot_lab_durable_session] = { store: @store, domain: 'test' }
        refute_nil Hook.current_session
        assert_equal 'test', Hook.current_session[:domain]
      end

      # ── skip_persist ─────────────────────────────────────────────────────────

      def test_skip_persist_suppresses_on_learn_for_block_duration
        Thread.current[:robot_lab_durable_session] = { store: @store, domain: 'test' }
        ctx = learn_ctx(text: 'suppressed', stored: true)

        Hook.skip_persist { Hook.on_learn(ctx) }

        assert_empty @store.recall(query: 'suppressed', domain: 'test', min_confidence: 0.0)
      end

      def test_skip_persist_clears_flag_after_block
        Hook.skip_persist { nil }
        assert_nil Thread.current[:robot_lab_durable_skip_persist]
      end

      def test_skip_persist_clears_flag_even_when_block_raises
        assert_raises(RuntimeError) { Hook.skip_persist { raise 'boom' } }
        assert_nil Thread.current[:robot_lab_durable_skip_persist]
      end

      # ── on_learn ─────────────────────────────────────────────────────────────

      def test_on_learn_persists_new_learning_when_session_active
        Thread.current[:robot_lab_durable_session] = { store: @store, domain: 'cooking' }
        ctx = learn_ctx(text: 'always salt pasta water', stored: true)

        Hook.on_learn(ctx)

        entries = @store.recall(query: 'pasta', domain: 'cooking', min_confidence: 0.0)
        assert_equal 1, entries.size
        assert_equal 'always salt pasta water', entries.first.content
        assert_equal :pattern, entries.first.category
        assert_equal 'cooking', entries.first.domain
      end

      def test_on_learn_skips_when_stored_false
        Thread.current[:robot_lab_durable_session] = { store: @store, domain: 'cooking' }
        ctx = learn_ctx(text: 'salt pasta water', stored: false)

        Hook.on_learn(ctx)

        assert_empty @store.recall(query: 'salt', domain: 'cooking', min_confidence: 0.0)
      end

      def test_on_learn_skips_when_no_session
        ctx = learn_ctx(text: 'orphaned learning', stored: true)

        Hook.on_learn(ctx)  # no session set — should be a no-op
      end

      def test_on_learn_skips_when_skip_persist_active
        Thread.current[:robot_lab_durable_session]      = { store: @store, domain: 'cooking' }
        Thread.current[:robot_lab_durable_skip_persist] = true
        ctx = learn_ctx(text: 'suppressed', stored: true)

        Hook.on_learn(ctx)

        assert_empty @store.recall(query: 'suppressed', domain: 'cooking', min_confidence: 0.0)
      end

      # ── around_run ───────────────────────────────────────────────────────────

      def test_around_run_sets_session_for_duration_of_block
        session_during_run = nil
        run_ctx = around_run_ctx(domain: 'finance')

        Hook.around_run(run_ctx) { session_during_run = Hook.current_session }

        refute_nil session_during_run
        assert_equal 'finance', session_during_run[:domain]
      end

      def test_around_run_clears_session_after_block
        run_ctx = around_run_ctx(domain: 'finance')
        Hook.around_run(run_ctx) { nil }
        assert_nil Hook.current_session
      end

      def test_around_run_clears_session_when_block_raises
        run_ctx = around_run_ctx(domain: 'finance')
        assert_raises(RuntimeError) { Hook.around_run(run_ctx) { raise 'boom' } }
        assert_nil Hook.current_session
      end

      def test_around_run_skips_setup_when_no_domain
        called = false
        run_ctx = around_run_ctx(domain: nil)

        Hook.around_run(run_ctx) { called = true }

        assert called
        assert_nil Hook.current_session
      end

      def test_around_run_uses_custom_store_path
        custom_dir = Dir.mktmpdir('custom_store')
        run_ctx    = around_run_ctx(domain: 'ops', store_path: custom_dir)
        session_during_run = nil

        Hook.around_run(run_ctx) { session_during_run = Hook.current_session }

        assert_equal custom_dir, session_during_run[:store].instance_variable_get(:@path)
      ensure
        FileUtils.rm_rf(custom_dir)
      end

      # ── seeding ──────────────────────────────────────────────────────────────

      def test_around_run_seeds_past_learnings_into_robot
        seed_entry('always document APIs', 'ruby', @store)
        run_ctx = around_run_ctx(domain: 'ruby')

        Hook.around_run(run_ctx) { nil }

        assert(@robot.learnings.any? { |l| l.include?('always document APIs') })
      end

      def test_seeded_learnings_are_not_repersisted_by_on_learn
        seed_entry('keep it simple', 'ruby', @store)
        run_ctx = around_run_ctx(domain: 'ruby')
        initial_count = @store.recall(query: 'simple', domain: 'ruby', min_confidence: 0.0).size

        Hook.around_run(run_ctx) { nil }

        after_count = @store.recall(query: 'simple', domain: 'ruby', min_confidence: 0.0).size
        assert_equal initial_count, after_count, 'seeded entry should not be re-persisted'
      end

      # ── integration: full learn cycle ─────────────────────────────────────────

      def test_new_learning_during_run_is_persisted_to_store
        run_ctx = around_run_ctx(domain: 'cooking')

        Hook.around_run(run_ctx) do
          ctx = learn_ctx(text: 'blanch vegetables before freezing', stored: true)
          Hook.on_learn(ctx)
        end

        entries = @store.recall(query: 'blanch', domain: 'cooking', min_confidence: 0.0)
        assert_equal 1, entries.size
        assert_equal 'blanch vegetables before freezing', entries.first.content
      end

      private

      def build_robot
        Struct.new(:learnings) do
          def initialize
            super([])
          end

          def learn(text)
            learnings << text unless learnings.include?(text)
            self
          end

          def name
            'test_robot'
          end
        end.new
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

      def around_run_ctx(domain:, store_path: @store_dir)
        ctx = RobotLab::RunHookContext.new(robot: @robot, request: 'test')
        ctx.with_namespace(:durable) do
          ctx.local.domain     = domain
          ctx.local.store_path = store_path
        end
        ctx
      end

      def seed_entry(content, domain, store)
        now = Time.now.iso8601
        store.record(
          Entry.new(
            content:    content,
            reasoning:  'seed',
            category:   :fact,
            domain:     domain,
            confidence: 0.5,
            use_count:  1,
            created_at: now,
            updated_at: now
          )
        )
      end
    end
  end
end
