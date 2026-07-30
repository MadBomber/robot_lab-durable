# robot_lab-durable

Cross-session durable memory for the [RobotLab](https://github.com/MadBomber/robot_lab) LLM agent framework, backed by the [htm gem](https://madbomber.github.io/htm) (PostgreSQL + pgvector).

> [!CAUTION]
> This gem is under active development. APIs may change without notice.

## What it provides

- **`Durable::Adapter`** — thin wrapper around an `HTM` instance; scoped to a robot by name. Exposes `record` and `recall` methods.
- **`Durable::Entry`** — presenter over raw HTM node hashes returned by recall. Provides typed fields: `node_id`, `content`, `reasoning`, `category`, `created_at`.
- **`Durable::Hook`** — RobotLab hook handler that wires the `Adapter` lifecycle into `around_run` and `on_learn` automatically.
- **`RecallKnowledge`** tool — lets a robot query its durable memory before answering.
- **`RecordKnowledge`** tool — lets a robot persist new knowledge during a session.

## Prerequisites

- PostgreSQL with the pgvector extension enabled.
- The `htm` gem — see documentation at https://madbomber.github.io/htm.
- The `robot_lab` gem.

## Installation

Add to your Gemfile:

```ruby
gem "robot_lab"
gem "robot_lab-durable"
```

Then run:

```
bundle install
```

## Quick Example

```ruby
require "robot_lab"
require "robot_lab/durable"

robot = RobotLab.build(
  name:          "advisor",
  system_prompt: "You are a financial advisor.",
  local_tools:   [RobotLab::RecallKnowledge, RobotLab::RecordKnowledge]
)
robot.on(RobotLab::Durable::Hook)

result = robot.run("What do you know about my risk tolerance?")
puts result.last_text_content
```

No `domain:` argument is required. HTM scopes all storage to the robot's `name` automatically.

## How It Works

### Hook lifecycle

`RobotLab::Durable::Hook` is registered via `robot.on(...)` and plugs into two lifecycle events:

- **`around_run`** — creates a thread-local `Adapter` instance keyed to `ctx.robot.name`, makes it available to tools for the duration of the run, and clears it in `ensure` so state never leaks across run boundaries.
- **`on_learn`** — fires after each new session learning is stored in memory. When a durable session is active, persists the text via `adapter.record(content:, category: :observation)`.

### Adapter

`Durable::Adapter` wraps an `HTM` instance and provides two methods:

| Method | Description |
|--------|-------------|
| `record(content:, reasoning: nil, category: 'fact')` | Stores a memory entry. HTM deduplicates by SHA-256 content hash, so calling `record` with identical content is safe. |
| `recall(query:, limit: 20, strategy: :hybrid)` | Searches stored memory and returns an array of `Entry` objects. |
| `htm` | Direct access to the underlying `HTM` instance for advanced use. |

### Entry

`Durable::Entry` is a presenter built via `Entry.from_node(node)` over the raw hashes returned by `HTM#recall`. It exposes:

| Field | Type | Description |
|-------|------|-------------|
| `node_id` | String | Unique HTM node identifier |
| `content` | String | The stored knowledge text |
| `reasoning` | String / nil | Optional rationale recorded at write time |
| `category` | Symbol | `:fact`, `:observation`, or any custom value |
| `created_at` | Time | When the entry was first stored |

## Tools

### RecallKnowledge

Calls `Hook.current_adapter.recall(query:)` with the query text provided by the LLM and returns formatted entries. Uses the `:hybrid` strategy by default.

### RecordKnowledge

Calls `adapter.record(content:, reasoning:, category:)` to persist a new memory, then calls `robot.learn(content)` to update session context. Because HTM deduplicates by content hash, no explicit double-write prevention is necessary.

## Day Trader Demo

`examples/01_day_trader.rb` demonstrates cross-session durable memory in action. It spawns a GBM stock price generator and an SMA+EMA ensemble predictor as subprocesses. Output is colour-coded `[GEN ]` / `[PRED]` per process, with a GOOD/MISS verdict printed for each prediction window. The durable agent tunes its prediction parameters across sessions, accumulating knowledge about what works.

```
ruby examples/01_day_trader.rb
```

## Links

- [RobotLab Core](https://github.com/MadBomber/robot_lab)
- [HTM gem docs](https://madbomber.github.io/htm)
- [RubyGems](https://rubygems.org/gems/robot_lab-durable)
- [GitHub](https://github.com/MadBomber/robot_lab-durable)

## License

MIT License — Copyright (c) 2025 Dewayne VanHoozer

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/MadBomber/robot_lab-durable.
