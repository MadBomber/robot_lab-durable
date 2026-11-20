# frozen_string_literal: true

module RobotLab
  class RecallKnowledge < Tool
    description 'Recall relevant knowledge from past sessions before making a decision. ' \
                'Use this when uncertain whether to include or skip content, or when you want ' \
                'to check if you have seen a similar situation before. ' \
                'When in doubt and no relevant knowledge is found, skip the action.'

    parameter :query, type: 'string', description: 'Natural language description of the decision you are about to make'

    def execute(query:)
      adapter = RobotLab::Durable::Hook.current_adapter
      return 'No durable session active on this robot.' unless adapter

      entries = adapter.recall(query: query)

      if entries.empty?
        "No relevant past knowledge found for: #{query}. When in doubt, skip."
      else
        "Relevant past knowledge:\n#{entries.map { |entry| format_entry(entry) }.join("\n")}"
      end
    end

    # One line per entry: "[category] content — reasoning". The reasoning part
    # is omitted when the entry has none (e.g. learnings persisted by on_learn).
    #
    # @param entry [RobotLab::Durable::Entry]
    # @return [String]
    def format_entry(entry)
      reasoning = entry.reasoning.to_s
      line      = "[#{entry.category}] #{entry.content}"
      reasoning.empty? ? line : "#{line} — #{reasoning}"
    end
  end
end
