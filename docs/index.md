# robot_lab-durable — Reference Documentation

Cross-session durable memory for the [RobotLab](https://github.com/MadBomber/robot_lab) LLM agent framework, backed by the [htm gem](https://madbomber.github.io/htm) (PostgreSQL + pgvector).

> [!CAUTION]
> This gem is under active development. APIs may change without notice.

## What it provides

- **`Durable::Adapter`** — thin wrapper around an `HTM` instance; scoped to a robot by name. Exposes `record` and `recall` methods plus direct `htm` access.
- **`Durable::Entry`** — presenter over raw HTM node hashes returned by recall. Provides typed fields.
- **`Durable::Hook`** — RobotLab hook handler that wires the `Adapter` lifecycle into `around_run` and `on_learn` automatically.
- **`RecallKnowledge`** tool — lets a robot query its durable memory before answering.
- **`RecordKnowledge`** tool — lets a robot persist new knowledge during a session.

## Prerequisites

- PostgreSQL with the pgvector extension enabled.
- The `htm` gem — see documentation at https://madbomber.github.io/htm.
- The `robot_lab` gem.

## Installation

```ruby
gem "robot_lab"
gem "robot_lab-durable"
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

---

## Adapter API

`Durable::Adapter` is initialised by `Hook#around_run` for each run and stored as a thread-local. It wraps `HTM.new(robot_name: name)`.

| Method | Arguments | Returns | Notes |
|--------|-----------|---------|-------|
| `record` | `content:` (String, required), `reasoning:` (String, optional), `category:` (String/Symbol, default `'fact'`) | Integer (HTM node_id) | Calls `htm.remember(content, metadata: { reasoning:, category: })`. HTM deduplicates by SHA-256 content hash — safe to call with the same content multiple times. |
| `recall` | `query:` (String, required), `limit:` (Integer, default 20), `strategy:` (Symbol, default `:hybrid`) | `Array<Entry>` | Calls `htm.recall(query, limit:, strategy:, raw: true)` then wraps each result in `Entry.from_node`. |
| `htm` | — | `HTM` instance | Direct access to the underlying HTM object for advanced operations. |

### Accessing the current adapter

```ruby
adapter = RobotLab::Durable::Hook.current_adapter
```

Returns the `Adapter` for the current thread, or `nil` when called outside an active `around_run`. Useful for direct access from custom tools or middleware.

### Direct HTM access

```ruby
adapter = RobotLab::Durable::Hook.current_adapter
raw_nodes = adapter.htm.recall("risk tolerance", strategy: :vector, raw: true)
```

Use `adapter.htm` when you need HTM operations not exposed through `Adapter`, such as bulk deletion or direct node inspection.

---

## Entry Fields

`Durable::Entry` is constructed via `Entry.from_node(node)` from a raw HTM node hash. HTM nodes use string keys (not symbols), so `from_node` reads `node['id']`, not `node[:id]`.

| Field | Type | Description | Source in HTM node |
|-------|------|-------------|--------------------|
| `node_id` | Integer | Unique identifier for the stored node | `node['id']` |
| `content` | String | The stored knowledge text | `node['content']` |
| `reasoning` | String / nil | Optional rationale recorded at write time | `node['metadata']['reasoning']` |
| `category` | Symbol | Category of knowledge (e.g. `:fact`, `:observation`) | `(node['metadata']['category'] || 'fact').to_sym` |
| `created_at` | String | Raw timestamp as returned by HTM (e.g. `'2026-05-06T12:00:00Z'`) — not parsed into a `Time` object | `node['created_at']` |

---

## Hook Lifecycle

The `Durable::Hook` handler implements two lifecycle callbacks.

### around_run

1. Reads `ctx.robot.name` from the run context.
2. Instantiates `Durable::Adapter.new(robot_name: name)`, which in turn creates `HTM.new(robot_name: name)`.
3. Stores the adapter as a thread-local so tools can reach it via `Hook.current_adapter`.
4. Yields to execute the actual robot run.
5. In `ensure`, clears the thread-local adapter so state never leaks to subsequent runs on the same thread.

### on_learn

Fires after each call to `robot.learn(text)`, but only persists when both of these hold:

1. `ctx.stored` is true — `robot.learn` sets this only when the text was actually added to the robot's in-memory `@learnings` list. If `text` is a substring of an existing learning (or vice versa, see `robot.learn`'s dedup rule in `robot_lab` core), `ctx.stored` stays `false` and `on_learn` returns early without recording.
2. A durable session is active (`Hook.current_adapter` is non-nil).

When both hold, calls:

```ruby
adapter.record(content: ctx.text, category: :observation)
```

This persists the learning immediately. HTM's content-hash deduplication ensures that re-seeding the same fact across sessions does not create duplicate entries.

### Enabling the hook

```ruby
robot.on(RobotLab::Durable::Hook)
```

No additional context keys are required. HTM scopes storage to the robot name automatically.

---

## Tools

### RecallKnowledge

Allows the LLM to query the robot's durable memory store.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `query` | String | yes | Natural-language description of the decision you are about to make |

`limit` and `strategy` are not exposed as tool parameters — the tool always calls `adapter.recall` with its defaults (`limit: 20`, `strategy: :hybrid`). Use `Hook.current_adapter` directly (see [Adapter API](#adapter-api)) if you need to control those.

Returns formatted text entries (`"[category] content — reasoning"`, one per line, prefixed with `"Relevant past knowledge:"`) when matches are found. Returns `"No relevant past knowledge found for: <query>. When in doubt, skip."` when the recall is empty, or `"No durable session active on this robot."` when no `Hook.current_adapter` is active (e.g. the hook wasn't registered with `robot.on`).

Implementation calls:

```ruby
Hook.current_adapter.recall(query: query)
```

### RecordKnowledge

Allows the LLM to persist new knowledge during a session.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `content` | String | yes | The knowledge text to store |
| `reasoning` | String | yes | Rationale or context for why this is being stored |
| `category` | String | yes | One of: fact, preference, pattern, correction |

All three are required — neither `param` (which defaults to `required: true`) nor the tool's `execute(content:, reasoning:, category:)` signature declares a default. (The `'fact'` default described in the [Adapter API](#adapter-api) applies only when calling `Adapter#record` directly, not through this tool.)

Returns `"Recorded: <content>"` on success, or `"No durable session active on this robot."` when no `Hook.current_adapter` is active.

Implementation calls:

```ruby
adapter.record(content: content, reasoning: reasoning, category: category)
robot.learn(content)
```

`robot.learn` updates the current session context so the LLM has immediate access to the new knowledge without waiting for the next run. Because HTM deduplicates by content hash, the subsequent `on_learn` callback does not produce a duplicate entry.

---

## HTM Recall Strategies

| Strategy | Mechanism | Best for |
|----------|-----------|----------|
| `:hybrid` | Combines vector similarity and full-text scoring | General use — recommended default |
| `:vector` | Embedding-based cosine similarity (pgvector) | Semantic / conceptual queries where exact keywords are unknown |
| `:fulltext` | PostgreSQL full-text search (tsvector / tsquery) | Keyword lookup, proper nouns, technical identifiers |

---

## Day Trader Demo

`examples/01_day_trader.rb` demonstrates cross-session durable memory in a quantitative trading context.

It spawns two subprocesses:

- **`[GEN ]`** — GBM (Geometric Brownian Motion) stock price generator.
- **`[PRED]`** — SMA+EMA ensemble predictor that issues directional forecasts.

Each prediction window receives a GOOD / MISS verdict printed to the terminal. The durable agent accumulates parameter tuning knowledge across sessions: window sizes, smoothing factors, and signal thresholds that worked well in past runs are recalled and applied, improving prediction accuracy over time.

```
ruby examples/01_day_trader.rb
```

---

## Migration Guide — v0.2.x to v0.3.0

v0.3.0 replaces the YAML file store, the `Durable::Store` class, the `Durable::Reflector`, the `Durable::Learning` mixin, and the `skip_persist` mechanism with a direct adapter over the `htm` gem. All domain/confidence concepts are gone.

### Gemfile

```ruby
# Before
gem "robot_lab-durable"

# After — htm gem is required; ensure PostgreSQL + pgvector are available
gem "robot_lab-durable"
gem "htm"
```

### Registering the hook

```ruby
# Before (v0.2.x)
robot.on(RobotLab::Durable::Hook, context: { domain: "finance" })

# After (v0.3.0) — no domain argument; scoped by robot name automatically
robot.on(RobotLab::Durable::Hook)
```

### Building a robot

```ruby
# Before (v0.2.x)
robot = RobotLab.build(
  name:         "advisor",
  system_prompt: "...",
  learn:        true,
  learn_domain: "finance"
)

# After (v0.3.0) — learn: / learn_domain: removed; use tools + hook instead
robot = RobotLab.build(
  name:          "advisor",
  system_prompt: "...",
  local_tools:   [RobotLab::RecallKnowledge, RobotLab::RecordKnowledge]
)
robot.on(RobotLab::Durable::Hook)
```

### Storage location

Before v0.3.0, knowledge was stored as YAML files under `~/.robot_lab/durable/`. In v0.3.0, all knowledge is stored in PostgreSQL via HTM. Existing YAML data is not migrated automatically — if you need to preserve past learnings, insert them into HTM using `adapter.record` before removing the old files.

### Removed classes

The following classes no longer exist and should be removed from any code that references them:

- `Durable::Store`
- `Durable::Reflector`
- `Durable::Learning` (mixin)
- `Hook.skip_persist` block helper

---

## Links

- [RobotLab Core](https://github.com/MadBomber/robot_lab)
- [HTM gem docs](https://madbomber.github.io/htm)
- [RubyGems](https://rubygems.org/gems/robot_lab-durable)
- [GitHub](https://github.com/MadBomber/robot_lab-durable)
