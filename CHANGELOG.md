## [Unreleased]

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
