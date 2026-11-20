# frozen_string_literal: true

module RobotLab
  class RecordKnowledge < Tool
    description 'Record a piece of knowledge learned during this session. ' \
                'Use after a decision or discussion reveals something worth remembering: ' \
                'a user preference, a reliable pattern, or a factual insight. ' \
                'Recorded knowledge persists across future sessions.'

    parameter :content,   type: 'string', description: 'The knowledge to record, in plain language (one clear statement)'
    parameter :reasoning, type: 'string',
                      description: 'Why this is worth remembering — the observation or discussion that led to it'
    parameter :category,  type: 'string', description: 'One of: fact, preference, pattern, correction'

    def execute(content:, reasoning:, category:)
      adapter = RobotLab::Durable::Hook.current_adapter
      return 'No durable session active on this robot.' unless adapter

      adapter.record(content: content, reasoning: reasoning, category: category)

      # Add the fact to the robot's session learnings (prepended to later runs).
      # HTM deduplicates by content hash, so the on_learn callback that follows is safe.
      learner&.learn(content)

      "Recorded: #{content}"
    end

    # The robot whose session learnings are updated: the tool's own robot when
    # it was attached as an instance (RecordKnowledge.new(robot: robot)),
    # otherwise the robot of the active durable run. A tool attached as a bare
    # class has no robot of its own.
    #
    # @return [RobotLab::Robot, nil]
    def learner
      robot || RobotLab::Durable::Hook.current_robot
    end
  end
end
