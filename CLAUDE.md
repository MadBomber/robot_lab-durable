# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Gem Does

`robot_lab-durable` gives RobotLab robots cross-session persistent memory backed by the `htm` gem (Hierarchical Temporal Memory). Knowledge is recorded by robots during a session and recalled in future sessions using hybrid semantic search (vector + full-text).

## Commands

```bash
bundle exec rake test        # Run full test suite
ruby -Ilib:test test/<file>  # Run a single test file
```

## Architecture

All source lives under `lib/robot_lab/durable/` plus two tool files at `lib/robot_lab/`.

**`Adapter`** (`durable/adapter.rb`) — Wraps an `HTM` instance for one robot. Two operations:
- `recall(query:, limit:, strategy:)` — calls `htm.recall` and maps nodes to `Entry` structs. Strategies: `:vector`, `:fulltext`, `:hybrid` (default). HTM's raw recall rows carry no metadata, so `metadata_for(node_ids)` fetches it in one `HTM::Models::Node` query (the model is injectable via `node_source:` for tests)
- `record(content:, reasoning:, category:)` — calls `htm.remember` with metadata hash

**`Entry`** (`durable/entry.rb`) — `Data.define(:node_id, :content, :reasoning, :category, :created_at)`. Immutable value object. `category` is always a Symbol. Built via `Entry.from_node(node)` from raw HTM node hashes.

**`Hook`** (`durable/hook.rb`) — Subclass of `RobotLab::Hook` with `namespace = :durable`. Manages a per-thread `Adapter` instance:
- `around_run` — creates an `Adapter` for the robot, stores it and the robot in `Thread.current` (`Hook.current_adapter` / `Hook.current_robot`), tears both down in `ensure`
- `on_learn` — called by the `:learn` hook family when the robot learns something; persists to HTM if `ctx.stored` is true

**`RecallKnowledge`** (`recall_knowledge.rb`) — `RobotLab::Tool` subclass. Takes a `query` param, calls `Hook.current_adapter.recall`, formats results for the LLM. Returns "No relevant past knowledge found" when empty — instructs the robot to skip rather than guess.

**`RecordKnowledge`** (`record_knowledge.rb`) — `RobotLab::Tool` subclass. Takes `content`, `reasoning`, `category` params. Calls `adapter.record` then `learner&.learn(content)` to update in-session memory immediately; `learner` is the tool's own robot or, for a tool attached as a bare class, `Hook.current_robot`. HTM deduplicates by content hash so double-writes are harmless.

## Enabling

```ruby
require 'robot_lab'
require 'robot_lab/durable'

robot = RobotLab.build(
  name:        "advisor",
  local_tools: [RobotLab::RecallKnowledge, RobotLab::RecordKnowledge]
)
robot.on(RobotLab::Durable::Hook)
# run() sends no tools by default; tools: :inherit sends the attached ones
result = robot.run("Remember my preference for concise answers.", tools: :inherit)
```

## Valid Categories

`fact`, `preference`, `pattern`, `correction`, `observation`

The LLM is free to choose — these are stored as metadata strings and returned as Symbols in `Entry#category`. First write wins: HTM does not update the metadata of content it already holds.

## Key Constraints

- The `Adapter` is scoped to `Thread.current` — it is NOT available across Ractors or Fibers.
- `RecordKnowledge` calls `robot.learn` internally; this triggers the `:learn` hook which calls `on_learn`. HTM deduplication prevents a double-write.
- `Hook` loads only when `RobotLab::Hook` is defined; `RecallKnowledge`/`RecordKnowledge` load only when `RobotLab::Tool` is defined. Always `require 'robot_lab'` before `require 'robot_lab/durable'`.
- The `htm` gem manages its own storage backend (PostgreSQL with vector extensions). Ensure the HTM database is configured before use.

## Testing

- Minitest with SimpleCov (branch coverage tracked, no minimum threshold enforced yet)
- Tests stub `HTM` — do not use a real database in unit tests. Fakes must return rows shaped like real HTM raw recall rows (no `'metadata'` key)
- Coverage baseline: ~98% line / ~84% branch
