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
    param :domain,    type: 'string', desc: "Topic area this applies to (e.g. 'newsletter curation', 'ruby tooling')"

    def execute(content:, reasoning:, category:, domain:)
      session = RobotLab::Durable::Hook.current_session
      return 'No durable session active on this robot.' unless session

      now   = Time.now.iso8601
      entry = Durable::Entry.new(
        content:,
        reasoning:,
        category:   category.to_sym,
        domain:,
        confidence: 0.1,
        use_count:  0,
        created_at: now,
        updated_at: now
      )

      # Write to the store with full metadata. Suppressing on_learn during
      # robot.learn() prevents a second generic write from the hook.
      RobotLab::Durable::Hook.skip_persist { session[:store].record(entry) }

      # Update session memory so subsequent LLM calls in this run see the fact.
      robot.learn("#{content} (#{domain})")

      "Recorded: #{content}"
    end
  end
end
