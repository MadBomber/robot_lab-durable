# robot_lab-durable

Cross-session durable learning for the [RobotLab](https://github.com/MadBomber/robot_lab) LLM agent framework.

> [!CAUTION]
> This gem is under active development. APIs may change without notice.

## What it provides

- **`Durable::Entry`** — immutable, confidence-tracked knowledge record
- **`Durable::Store`** — YAML-backed, file-locked per-domain knowledge persistence in `~/.robot_lab/durable/`
- **`Durable::Reflector`** — promotes session-level learnings into the durable store at end-of-run
- **`Durable::Learning`** — mixin included into `RobotLab::Robot`; enabled via `learn: true, learn_domain:` constructor params
- **`RecallKnowledge`** tool — lets robots query the durable store before making decisions
- **`RecordKnowledge`** tool — lets robots write new knowledge during a session

## Installation

Add to your Gemfile:

```ruby
gem "robot_lab"
gem "robot_lab-durable"
```

## Quick Example

```ruby
require "robot_lab"
require "robot_lab/durable"

robot = RobotLab.build(
  name: "advisor",
  system_prompt: "You are a financial advisor that learns from each session.",
  learn: true,
  learn_domain: "finance"
)

# RecallKnowledge and RecordKnowledge tools are automatically available.
# At the end of each run, the Reflector promotes learned facts to
# ~/.robot_lab/durable/finance.yml for use in future sessions.
result = robot.run("What do you know about my risk tolerance?")
puts result.last_text_content
```

## How It Works

When `learn: true` and `learn_domain:` are set, the robot gains two built-in tools:

- **`RecallKnowledge`** — queries the domain's YAML store for relevant past knowledge before responding
- **`RecordKnowledge`** — writes new knowledge entries during a session

At the end of each run, `Durable::Reflector` promotes session-level learnings into the persistent store with confidence scoring and deduplication.

## Knowledge Persistence

```
~/.robot_lab/durable/
  finance.yml       # per-domain YAML store
  support.yml
  ...
```

Each entry records: `content`, `confidence`, `category`, `domain`, `use_count`, `created_at`, and `updated_at`.

Knowledge confidence grows as the same fact is recalled and confirmed across sessions. Low-confidence entries are pruned automatically over time.

## Relationship to `robot.learn()`

`robot.learn()` is a core RobotLab method that accumulates observations within a single session in memory. `robot_lab-durable` extends this by persisting those observations to disk across sessions, making the robot's learning accumulate over its lifetime rather than resetting each run.

## Links

- [RobotLab Core](https://github.com/MadBomber/robot_lab)
- [RubyGems](https://rubygems.org/gems/robot_lab-durable)

## License

MIT License - Copyright (c) 2025 Dewayne VanHoozer

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/MadBomber/robot_lab-durable.
