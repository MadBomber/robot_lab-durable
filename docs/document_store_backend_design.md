# Delegate Storage to robot_lab-document_store — Design Discussion

**Date:** 2026-05-14
**Original status:** Parked — resume when time allows
**Current status:** Superseded — see [docs/index.md](index.md)

The document_store delegation path was abandoned. In v0.3.0, `robot_lab-durable` became a direct adapter over the [`htm` gem](https://madbomber.github.io/htm) (PostgreSQL + pgvector), replacing the YAML store, the `Durable::Store` class, `Durable::Reflector`, and all domain/confidence concepts entirely. The open questions raised here — search semantics, structured metadata, backend versioning — are resolved by HTM's native hybrid recall and metadata hash support.

For the current architecture, see [docs/index.md](index.md) and the [HTM gem documentation](https://madbomber.github.io/htm).
