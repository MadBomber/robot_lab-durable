# frozen_string_literal: true

module RobotLab
  module Durable
    class Hook < RobotLab::Hook
      self.namespace = :durable

      class << self
        # Initialize an HTM-backed adapter for the robot and make it available
        # thread-locally for the duration of the run, then tear it down.
        def around_run(ctx, &block)
          robot_name = ctx.robot.name || 'default'
          set_adapter(Adapter.new(robot_name: robot_name))
          block.call
        ensure
          clear_adapter
        end

        # Persist new session learnings to HTM long-term memory.
        # HTM deduplicates by content hash, so double-writes from RecordKnowledge
        # are harmless — the second call simply increments remember_count.
        def on_learn(ctx)
          return unless ctx.stored

          adapter = current_adapter
          return unless adapter

          adapter.record(content: ctx.text, category: :observation)
        end

        # Returns the active durable adapter for the current thread, or nil.
        def current_adapter
          Thread.current[:robot_lab_durable_adapter]
        end

        private

        def set_adapter(adapter)
          Thread.current[:robot_lab_durable_adapter] = adapter
        end

        def clear_adapter
          Thread.current[:robot_lab_durable_adapter] = nil
        end
      end
    end
  end
end
