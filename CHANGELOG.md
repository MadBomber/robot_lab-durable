## [Unreleased]

### Added
- `.loki` Asgard task file: `test`, `rubocop`, `rubocop_fix`, `flog`, `flay`, `quality`, `build`, `install`, `release`, and `console` tasks via the Asgard task runner
- `flay_check` Rake task: structural code duplication gate (mass threshold 50); integrated into the `quality` Rake task
- `flay` and `minitest-reporters` gems added to development dependencies
- `test_output.txt`, `flay_output.txt`, `flog_output.txt`, and `rubocop_output.txt` added to `.gitignore`

### Changed
- `test/test_helper.rb`: test output redirected to `test_output.txt` via `$stdout` reassignment; `TerminalSummaryReporter` prints a single PASS/FAIL summary line to the terminal
- `Rakefile`: `rubocop` and `rubocop_fix` tasks removed (now owned by Asgard); `flay_check` integrated into the `quality` gate

## [0.3.0] - 2026-05-24

### Changed (breaking)
- **Backend replaced**: YAML file store replaced entirely by the `htm` gem (PostgreSQL + pgvector).
  `robot_lab-durable` is now a thin adapter between `robot_lab` and `htm`.
- `Durable::Entry` is now a presenter built from HTM node hashes via `Entry.from_node(node)`.
  Removed fields: `domain`, `confidence`, `use_count`. Added: `node_id`.
- `Durable::Hook` no longer manages a domain or seeds past knowledge into session memory.
  `around_run` initialises a thread-local `Adapter` from `ctx.robot.name`; `on_learn` persists
  new learnings via `adapter.record`. `Hook.current_adapter` returns the active adapter.
- `RecallKnowledge` and `RecordKnowledge` now delegate to `Hook.current_adapter` instead of a
  YAML store. The `domain:` parameter is removed from both tools.
- `Gemfile` updated: depends on published `htm` gem and local `robot_lab` path.

### Added
- `Durable::Adapter` — wraps `HTM.new(robot_name:)`, exposes `recall(query:, ...)` and
  `record(content:, reasoning:, category:)`. HTM deduplicates by content hash, eliminating
  the need for double-write prevention.
- Full test suite for `Durable::Adapter` (`test/robot_lab/durable/adapter_test.rb`) using a
  `FakeHTM` stand-in — no PostgreSQL required.
- `examples/01_day_trader.rb` — demo launcher that spawns the generator and predictor as
  subprocesses and relays their output with colour-coded `[GEN ]`/`[PRED]` prefixes.
- `examples/day_trader_lib/generator.rb` — XYZZY fake stock price stream via Redis (GBM model).
- `examples/day_trader_lib/predictor.rb` — SMA+EMA ensemble tuned by a durable agent;
  prints `✓ GOOD / ✗ MISS` verdict after each prediction window.

### Removed
- `Durable::Store` (YAML-backed per-domain file store).
- `Durable::Reflector` (end-of-run confidence promoter).
- `domain` concept throughout — HTM uses `robot_name` for scoping.
- `skip_persist` mechanism — HTM SHA-256 content deduplication makes it unnecessary.

## [0.2.1] - 2026-05-19

### Added
- `Durable::Entry` — immutable `Data.define` value object with `content`, `confidence`, `category`, `domain`, `use_count`, `created_at`, and `updated_at` fields
- `Durable::Store` — YAML-backed, file-locked per-domain knowledge persistence in `~/.robot_lab/durable/`
- `Durable::Reflector` — promotes session-level learnings into the durable store at end-of-run with confidence scoring and deduplication
- `Durable::Learning` mixin — included into `RobotLab::Robot` when `learn: true` and `learn_domain:` constructor params are set
- `RecallKnowledge` tool — lets robots query the durable store before making decisions
- `RecordKnowledge` tool — lets robots write new knowledge entries during a session
- Design document for future `DocumentStore::FileSystem` backend integration (`docs/document_store_backend_design.md`)

### Changed
- Version synchronized with robot_lab core 0.2.1

## [0.1.0] - 2026-05-07

- Initial release
