# swift-linter-rules

L3-Foundations package shipping the institute-canonical SwiftSyntax-based
lint rule catalog.

## What it is

A third-party-adoptable rule library: each rule conforms to
`Linter Primitives` (the L1 protocol surface) and emits diagnostics
citing the institute skill / memory rule it enforces. Designed to be
consumed by `swift-linter` (the executable / CLI / reporter shell) AND
by any third-party tool that wants the same rule predicates without the
linter shell.

## What's here (Phase 3 catalog)

- `Linter Rule Unchecked` — R5: forbids `__unchecked:` at call sites
  (CONV-016).
- `Linter Rule Cardinal` — R1: forbids `count - 1` patterns where a
  typed Cardinal would prevent the underflow (INFRA-200).
- `Linter Rule RawValue` — chained `.rawValue.method()` patterns that
  escape the typed system (CONV-016, INFRA-103).
- `Linter Rule ResultBuilder` — `for i in 0..<N { i }` in builder
  bodies (carry-forward Phase 2 rule).

Phase 4 lands a wave of 7 additional rules encoded against
institute skills + auto-memory feedback (separate dispatch per
`HANDOFF-swift-linter-rules-wave-1-encoding.md`).

## Layer position

Layer 3 (Foundations). Depends on `swift-linter-primitives` (L1
protocol surface) and `swift-syntax` (Apple). Foundation-clean per
`[PRIM-FOUND-001]` cascade.

## Consumers

- `swift-foundations/swift-linter` — primary consumer; the CLI
  shell composes rules + reporters + manifest resolution.
- (Future) third-party tooling — same rule predicates without the
  linter executable.

## Status

Pre-1.0. The catalog is structurally stable; rule predicate logic
is unchanged from Phase 2's pre-extraction state.
