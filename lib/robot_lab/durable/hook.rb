# frozen_string_literal: true

module RobotLab
  module Durable
    class Hook < RobotLab::Hook
      self.namespace = :durable

      class << self
        # Set up the durable session for this run: open the store, seed past
        # learnings into the robot's session memory, execute the run, then
        # tear down the session in ensure so it never leaks across run boundaries.
        #
        # Requires ctx.local.domain to be set (via the context: kwarg on on()).
        # Without a domain the block is called without durable involvement.
        def around_run(ctx, &block)
          ns         = ctx.ext(:durable)
          domain     = ns.domain
          return block.call unless domain

          store_path = ns.store_path
          store      = Store.new(**(store_path ? { path: store_path } : {}))

          set_session(store: store, domain: domain)
          seed_from_store(ctx.robot, store, domain)

          block.call
        ensure
          clear_session
        end

        # Persist a new session learning to long-term storage immediately after
        # it is added to the robot's session memory.
        #
        # Skipped when:
        #   - persist is suppressed (seeding recalled entries back into session,
        #     or RecordKnowledge has already written with full metadata)
        #   - ctx.stored is false (entry was deduplicated at the session level)
        #   - no durable session is active for this thread
        def on_learn(ctx)
          return if skip_persist?
          return unless ctx.stored

          session = current_session
          return unless session

          now = Time.now.iso8601
          session[:store].record(
            Entry.new(
              content:    ctx.text,
              reasoning:  'Promoted from session learning',
              category:   :pattern,
              domain:     session[:domain],
              confidence: 0.1,
              use_count:  0,
              created_at: now,
              updated_at: now
            )
          )
        end

        # Returns the active durable session hash for the current thread, or nil.
        # Shape: { store: Store, domain: String }
        def current_session
          Thread.current[:robot_lab_durable_session]
        end

        # Run block with on_learn persistence suppressed. Used internally during
        # seeding and by RecordKnowledge to prevent double-writes when rich
        # metadata is already being persisted directly.
        def skip_persist
          Thread.current[:robot_lab_durable_skip_persist] = true
          yield
        ensure
          Thread.current[:robot_lab_durable_skip_persist] = nil
        end

        private

        def set_session(store:, domain:)
          Thread.current[:robot_lab_durable_session] = { store: store, domain: domain }
        end

        def clear_session
          Thread.current[:robot_lab_durable_session] = nil
        end

        def skip_persist?
          Thread.current[:robot_lab_durable_skip_persist]
        end

        def seed_from_store(robot, store, domain)
          skip_persist do
            entries = store.recall(query: domain, domain: domain, min_confidence: 0.0)
            entries.each do |e|
              robot.learn("[#{e.category}] #{e.content}: #{e.reasoning}")
            end
          end
        end
      end
    end
  end
end
