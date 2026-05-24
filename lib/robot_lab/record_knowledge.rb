# frozen_string_literal: true

module RobotLab
  class RecordKnowledge < Tool
    description 'Record a piece of knowledge learned during this session. ' \
                'Use after a decision or discussion reveals something worth remembering: ' \
                'a user preference, a reliable pattern, or a factual insight. ' \
                'Recorded knowledge persists across future sessions.'

    param :content,   type: 'string', desc: 'The knowledge to record, in plain language (one clear statement)'
    param :reasoning, type: 'string',
                      desc: 'Why this is worth remembering — the observation or discussion that led to it'
    param :category,  type: 'string', desc: 'One of: fact, preference, pattern, correction'

    def execute(content:, reasoning:, category:)
      adapter = RobotLab::Durable::Hook.current_adapter
      return 'No durable session active on this robot.' unless adapter

      adapter.record(content: content, reasoning: reasoning, category: category)

      # Update session memory so subsequent LLM calls in this run see the fact.
      # HTM deduplicates by content hash, so the on_learn callback that follows is safe.
      robot.learn(content)

      "Recorded: #{content}"
    end
  end
end
