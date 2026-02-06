# Modularization Plan

Last updated: 2026-02-06

## Summary
Modularize the iOS codebase incrementally to maximize platform-agnostic reuse for future multi-platform clients. Extract leaf modules first, enforce strict boundaries, and keep behavior changes out of structural moves.

## Scope
In scope:
- Shared Swift package at `apps/common` with platform-neutral targets.
- Incremental extraction of low-level modules from `apps/ios/GuideDogs/Code`.
- Test coverage for new shared targets using Swift Testing.

Out of scope (for early phases):
- Localization/resource migration.
- Large behavior pipeline refactors beyond boundary prep.

## Boundary Rules
- `apps/common/Sources` must stay platform-agnostic.
- No imports of Apple UI/platform frameworks in `apps/common/Sources`.
- iOS app targets may depend on `apps/common`; never the reverse.
- Validate boundaries with `bash apps/common/Scripts/check_forbidden_imports.sh`.

## Current Status
Phase 1 complete:
- Shared package created: `apps/common/Package.swift`.
- Module extracted: `SSDataStructures`.
- Extracted types moved from iOS app code:
  - `BoundedStack`, `LinkedList`, `Queue`, `CircularQuantity`, `ThreadSafeValue`, `Token`, `Array+CircularQuantity`.
- Package test target added:
  - `apps/common/Tests/SSDataStructuresTests`.
- CI updated to run common boundary check + package tests before iOS build/test.

## Progress Updates
- 2026-02-06: Completed first extraction (`SSDataStructures`) and integrated it into iOS target dependencies.
- 2026-02-06: Added boundary enforcement script for forbidden platform imports in `apps/common/Sources`.
- 2026-02-06: Added Swift Testing coverage for extracted data-structure module.
- 2026-02-06: Renamed common module naming to `SS*` convention and updated first module name from `SoundscapeCoreDataStructures` to `SSDataStructures`.

## Next Steps
1. Evaluate `SSUniversalLinks` extraction and keep only platform-neutral URL/domain primitives in `apps/common`.
2. Identify and extract additional leaf primitives (offline/build/version/value types) with minimal dependencies.
3. Add/maintain module-level tests for each new shared target using Swift Testing.
4. Keep this document and `AGENTS.md` updated after each extraction with:
   - new module name,
   - status,
   - immediate next step.
