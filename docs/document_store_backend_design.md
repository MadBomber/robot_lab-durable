# Delegate Storage to robot_lab-document_store — Design Discussion

**Date:** 2026-05-14
**Status:** Parked — resume when time allows

## The Problem

`robot_lab-durable` currently maintains its own `Store` class: a YAML-backed, file-locked, keyword-search storage layer in `lib/robot_lab/durable/store.rb`. This is duplicated effort — `robot_lab-document_store` is intended to be the canonical pluggable storage abstraction for the robot_lab ecosystem.

## The Vision

Once `robot_lab-document_store` gains a `DocumentStore::FileSystem` backend, durable should drop its custom `Store` class and delegate physical storage to it. Durable retains its own concerns:

- `Entry` — immutable value object with confidence scoring, category, domain, use_count
- `Reflector` — end-of-session promoter that pushes session learnings into the store
- `Learning` — mixin included into `Robot` when robot_lab is present
- `RecallKnowledge` / `RecordKnowledge` — LLM tools that interact with the store

## What Changes in This Gem

1. Add `robot_lab-document_store` as a runtime dependency in the gemspec.
2. Remove `lib/robot_lab/durable/store.rb`.
3. Wire `Learning#setup_durable_learning` to instantiate a `DocumentStore::FileSystem` instead of `Durable::Store`.
4. Adapt `Reflector` and the two tools to call the `DocumentStore` interface (`store`, `search`, `delete`, etc.) rather than the old `Store` API.
5. Handle `Entry` serialization — since `DocumentStore` stores raw text by key, durable will serialize `Entry` fields into text (or use a metadata hash if `FileSystem` supports it — see open questions).

## Open Questions (shared with robot_lab-document_store)

1. **Search semantics.** `DocumentStore::Memory` uses embedding-based cosine similarity; `DocumentStore::FileSystem` would use keyword matching. Should the interface declare its search capability, or do callers accept whatever the backend provides?

2. **Structured vs raw text.** `Entry` carries structured fields (confidence, category, domain, use_count). Options:
   - Durable serializes all fields into the stored text string; deserializes on recall.
   - `DocumentStore::FileSystem` supports an optional `meta:` Hash alongside text, which durable populates with `Entry` fields.

## Versioning

- `robot_lab-document_store` must ship `DocumentStore::FileSystem` first — that is a v0.3.0 breaking change for that gem (v0.2.1 is the current release).
- This gem (`robot_lab-durable`) then bumps to v0.3.0 once it drops `Store` and depends on document_store.

## See Also

`robot_lab-document_store/docs/pluggable_backends_design.md` — the full backend architecture design including the `DocumentStore` abstract interface and implementation plan.
