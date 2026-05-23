# robot_lab-durable

Cross-session durable learning for the [RobotLab](https://github.com/MadBomber/robot_lab) LLM agent framework.

> [!CAUTION]
> This gem is under active development. APIs may change without notice.

## What it provides

- **`Durable::Entry`** — immutable, confidence-tracked knowledge record
- **`Durable::Store`** — YAML-backed, file-locked per-domain knowledge persistence in `~/.robot_lab/durable/`
- **`Durable::Hook`** — hook handler that wires durable learning into the RobotLab lifecycle
- **`Durable::Reflector`** — batch promoter for migrating session learnings into the store (manual / migration use)
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
  name:         "advisor",
  system_prompt: "You are a financial advisor that learns from each session.",
  local_tools:  [RobotLab::RecallKnowledge, RobotLab::RecordKnowledge]
)

# Enable durable learning for this robot, scoped to the "finance" domain.
robot.on(RobotLab::Durable::Hook, context: { domain: "finance" })

# Each run seeds the robot with past knowledge from ~/.robot_lab/durable/finance.yml,
# and any new learnings are persisted back to that file automatically.
result = robot.run("What do you know about my risk tolerance?")
puts result.last_text_content
```

## How It Works

`RobotLab::Durable::Hook` is a RobotLab hook handler that plugs into the `:run` and `:learn`
lifecycle events:

- **`around_run`** — opens the domain's YAML store, seeds past knowledge into the robot's session
  memory via `robot.learn()`, executes the run, then tears down the session in `ensure` so state
  never leaks across run boundaries.

- **`on_learn`** — fires after each new session learning is stored in memory. Persists the text
  immediately to the domain's YAML store with a baseline confidence score.

### Enabling on a robot

```ruby
robot.on(RobotLab::Durable::Hook, context: { domain: "finance" })
```

The `context:` hash is merged into the hook's namespace-isolated state on each call:

| Key | Required | Description |
|-----|----------|-------------|
| `domain` | yes | Topic area; maps to `~/.robot_lab/durable/<domain>.yml` |
| `store_path` | no | Override the default store directory |

Without a `domain`, `around_run` is a no-op — the hook silently yields without setting up storage.

### Enabling globally (all robots)

```ruby
RobotLab.on(RobotLab::Durable::Hook, context: { domain: "shared" })
```

### Preventing double-writes

`RecordKnowledge` writes a rich `Entry` directly to the store (with category, reasoning, and
confidence) and then calls `robot.learn()` to update session memory. To prevent `on_learn`
from writing a second, generic entry for the same fact, `RecordKnowledge` wraps its store write
in `Hook.skip_persist { }`.

The same mechanism protects the seeding phase in `around_run`: past learnings are fed back into
`robot.learn()` without re-persisting them.

## Knowledge Persistence

```
~/.robot_lab/durable/
  finance.yml           # per-domain YAML store
  xyzzy_stock_prediction.yml
  ...
```

Each entry records: `content`, `confidence`, `category`, `domain`, `reasoning`, `use_count`,
`created_at`, and `updated_at`. Knowledge confidence grows as the same fact is recalled and
confirmed across sessions.

## Relationship to `robot.learn()`

`robot.learn()` is a core RobotLab method that accumulates observations within a single session.
`robot_lab-durable` extends this: whenever `on_learn` fires and a durable session is active, the
new text is immediately persisted. At the start of the next session `around_run` re-seeds those
facts, so the robot's learning accumulates over its lifetime rather than resetting each run.

## Links

- [RobotLab Core](https://github.com/MadBomber/robot_lab)
- [RubyGems](https://rubygems.org/gems/robot_lab-durable)

## License

MIT License - Copyright (c) 2025 Dewayne VanHoozer

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/MadBomber/robot_lab-durable.
