# frozen_string_literal: true

module RobotLab
  class RecallKnowledge < Tool
    description 'Recall relevant knowledge from past sessions before making a decision. ' \
                'Use this when uncertain whether to include or skip content, or when you want ' \
                'to check if you have seen a similar situation before. ' \
                'When in doubt and no relevant knowledge is found, skip the action.'

    param :query, type: 'string', desc: 'Natural language description of the decision you are about to make'

    def execute(query:)
      adapter = RobotLab::Durable::Hook.current_adapter
      return 'No durable session active on this robot.' unless adapter

      entries = adapter.recall(query: query)

      if entries.empty?
        "No relevant past knowledge found for: #{query}. When in doubt, skip."
      else
        lines = entries.map { |e| "[#{e.category}] #{e.content} — #{e.reasoning}" }
        "Relevant past knowledge:\n#{lines.join("\n")}"
      end
    end
  end
end
