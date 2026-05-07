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

## Knowledge Persistence

```
~/.robot_lab/durable/
  finance.yml       # per-domain YAML store
  support.yml
  ...
```

Each entry records `content`, `confidence`, `category`, `domain`, `use_count`, `created_at`, and `updated_at`.

## Links

- [Implementation Plan](superpowers/plans/2026-05-06-durable-learning.md)
- [Design Spec](superpowers/specs/2026-05-06-durable-learning-design.md)
- [RobotLab Core](https://github.com/MadBomber/robot_lab)
- [RubyGems](https://rubygems.org/gems/robot_lab-durable)
