# Wave 3 Aggregate — Post-Amendment Validation

<!--
---
version: 1.1.0
last_updated: 2026-05-11
status: IMPLEMENTED
---
-->

## Changelog

- **v1.1.0 (2026-05-11)** — appended:
  - stdlib-extensions Lint build defect fixed (swift-primitives/swift-standard-library-extensions commit `02ac34f`); re-ran lint to obtain the 11-package number (0 findings).
  - Thread 2 partial-gap closed via follow-up amendment (swift-linter-rules commit `ac40ca1`); 1 residual `extension noncopyable constraint` finding on `Erased.Incoming:57` no longer fires.
  - Updated per-target table and totals to reflect both fixes.
- **v1.0.0 (2026-05-11)** — initial 9-of-10-packages aggregate; documented stdlib-extensions build defect + Thread 2 partial-gap as follow-ups.

## Context

Wave 3 dispatch (HANDOFF.md) landed 5 rule-amendment commits across two
rule packages, plus 3 RECOMMENDATION research docs for the queued
policy/design questions. This ledger captures the post-amendment
aggregate lint pass against the same 10 leaf packages used for the
2026-05-11 pre-amendment baseline (`lint-pass-2026-05-11-aggregate.md`).

**Engine**: swift-linter @ `86856c1` (branch `lint-pass-audit-2026-05-11`)
— two commits ahead of baseline (`17a9777`), both pre-Wave-3:
- `b060fb3` Three-tier hierarchy: drop rule deps; hoist Lint.run() helper
- `86856c1` Exclude `*.docc/**` from source discovery; add path-substring safety net

**Rule packages**: 
- swift-linter-rules @ `d18e62a` — includes Wave 3 #1, #2, #5 (commits f89c4d4, 4f85e1a, d18e62a)
- swift-institute-linter-rules @ `686f208` — includes Wave 3 #3, #4 (commits 02cab07, 686f208)

**Lint executable build**: per-package `Lint/` nested sub-package; path-
deps onto rule packages pick up Wave 3 amendments locally without
`swift package update`.

## Per-target totals

| Target | Baseline | Wave 3 | Δ | Notes |
|--------|---------:|-------:|---:|------|
| swift-carrier-primitives | 18 | 0 | -18 | DocC findings cleared via engine exclusion (86856c1); MEM-COPY + minimal Protocol closed by Wave 2 ledger entries |
| swift-comparison-primitives | 45 | 0 | -45 | DocC + Wave 2 closeouts |
| swift-either-primitives | 6 | 0 | -6 | Compound `flatMap` exempted via stdlib-idiom citations (Wave 2 ledger #1) |
| swift-equation-primitives | 55 | 0 | -55 | DocC + Wave 2 closeouts |
| swift-hash-primitives | 46 | 0 | -46 | DocC + Wave 2 closeouts |
| swift-ownership-primitives | 56 | 11 | -45 | 11 RULE-WRONG/HELD residuals remain (see breakdown below — v1.1.0 closed the prior 12th via Thread 2 extension `ac40ca1`) |
| swift-product-primitives | 13 | 0 | -13 | MEM-COPY pack-expansion + Existential — Wave 2 ledger amendments |
| swift-property-primitives | 15 | 1 | -14 | 1 AMBIGUOUS held vs [MEM-SAFE-025] — see Thread 7 |
| swift-standard-library-extensions | 620 | 0 | -620 | v1.1.0: Lint sub-package build defect fixed (`02ac34f`); re-ran clean. All 620 baseline findings closed via combined engine DocC exclusion + Wave 2 source-fixes (d19e725) + `.disable(.\`int public parameter\`)` directive (54) + Wave 3 amendments |
| swift-tagged-primitives | 22 | 0 | -22 | Tagged-init + bridge + Compound closeouts |
| **Total (11 packages)** | **896** | **12** | **-884** | **98.7% drop ecosystem-wide** |

The 263-finding drop on the 9 cleanly-building packages confirms the
handoff's prediction ("compound identifier findings drop materially
due to local-var scope gate; docc findings clear via engine
exclusion"). The compound_identifier rule's 363 baseline findings
were dominated by DocC step-files (the per-leaf reports cited
`Carrier Primitives.docc/Resources/step-*` paths as the bulk); the
engine's `*.docc/**` exclusion (`86856c1`, landed pre-Wave-3 but
post-baseline) removes those without rule changes.

## Per-rule breakdown of remaining 12 findings

All 12 residuals are in swift-ownership-primitives (11) +
swift-property-primitives (1).

### swift-ownership-primitives — 11 findings

| Rule | Count | Disposition |
|------|------:|-------------|
| compound identifier | 6 | 4 = API-rename decision (`takeIfPresent` / `consumeIfStored` × 4 on `Slot.Move` + retained-incoming/outgoing) deferred per HANDOFF Open Q3; 2 = `destroyPayload` / `payloadOffset` (Erased.Outgoing.Header fileprivate) RULE-WRONG against private-surface applicability — Thread 4 research doc surfaces the rule-policy question |
| unchecked sendable noncopyable | 3 | HELD vs [MEM-SAFE-025] reconciliation — Thread 7 research doc surfaces the policy question (Option A/B/C); decision unblocks |
| unchecked call site | 2 | `Slot.Move.in` / `Slot.Move.out` bottom-out delegators — genuine institute escape hatches per [CONV-016]; Thread 8 research doc surfaces the per-finding disable mechanism design (Option D hybrid recommended) |
| ~~extension noncopyable constraint~~ | ~~1~~ | **CLOSED in v1.1.0** via Thread 2 extension (`ac40ca1`) — `consuming-self func` with own generic params on non-generic extended type now exempt; `Erased.Incoming:57` no longer fires |

### swift-property-primitives — 1 finding

| Rule | Count | Disposition |
|------|------:|-------------|
| unchecked sendable categorization | 1 | `Property.Consume.State.swift:54` — AMBIGUOUS held vs [MEM-SAFE-025] reconciliation — Thread 7 unblocks |

## Wave 3 thread-by-thread validation

| Thread | Wave 3 deliverable | Baseline finding | Post-amendment | Result |
|--------|--------------------|------------------|----------------|--------|
| #1 — ExtensionNoncopyableConstraint nested-type skip | Code amendment (f89c4d4) + 3 tests | 6 RULE-WRONG | 0 of these 6 remain | ✓ Closed |
| #2 — ExtensionNoncopyableConstraint method-local generics | Code amendment (4f85e1a) + 4 tests; **v1.1.0 extension** `ac40ca1` adds consuming-self/own-generics exemption + 3 tests | 1 RULE-WRONG | 0 of these remain (both parameter-shape AND consuming-self shape now exempt) | ✓ Closed (v1.1.0) |
| #3 — NamingCompound SE-0517 mutableSpan/span exemption | Code amendment (02cab07) + 2 tests | 1 RULE-WRONG | 0 of this 1 remains | ✓ Closed |
| #4 — NamingCompound private-surface policy | Research doc (api-name-002-private-surface-applicability.md) | 2 RULE-WRONG (held) | 2 still fire (held vs policy decision) | ◐ Surfaced; decision pending |
| #5 — BoxClass canonical-CoW-backing exemption | Code amendment (686f208) + 4 tests | 1 RULE-WRONG (ad_hoc_box_class on Indirect.Storage) | 0 of this 1 remains | ✓ Closed |
| #6 — InlinableInternalAccess init-specific message | Code amendment (d18e62a) + 3 tests | 0 (Wave 2 source-fix already closed) | n/a — message-quality amendment, not a finding-count amendment | ✓ Closed (consumer-experience improvement) |
| #7 — [MEM-SAFE-025] reconciliation | Research doc (mem-safe-025-reconciliation.md) | 3 unchecked-sendable-noncopyable + 1 AMBIGUOUS (held) | 4 still fire (held vs policy decision) | ◐ Surfaced; decision pending |
| #8 — Per-finding disable mechanism | Research doc (swift-linter-per-finding-disable-mechanism.md) | 2 unchecked-call-site (held) | 2 still fire (held vs engine design decision) | ◐ Surfaced; decision pending |

## Wave 3 amendment summary

- **5 rule amendments landed** (Threads #1, #2, #3, #5, #6) across 2 rule packages, 12 new tests added (cumulative new tests pass = 12; total tests pass).
- **3 RECOMMENDATION research docs landed** (Threads #4, #7, #8) at `swift-institute/Research/`; decisions pending user/principal stamps.
- **884 finding drop** ecosystem-wide (v1.1.0 11-package number after stdlib-extensions build fix; Wave 3 ledger commits + Wave 2 carry-over + engine DocC exclusion + stdlib-ext disable directive combined).

## Residuals after Wave 3 (v1.1.0)

The 12 remaining findings split into:

- **8 held vs policy decisions** (Threads #4 + #7 + #8 unblock 2 + 4 + 2 respectively)
- **4 API-rename decision** (HANDOFF Open Q3: takeIfPresent / consumeIfStored rename to nested accessor; breaking API)

The Wave 3 dispatch is **substantially closed** with all residuals
fully understood and mapped to either (a) pending user decisions on
Threads #4/#7/#8 or (b) the deferred API-rename pass (Open Q3). The
v1.0.0 Thread 2 partial-gap is now closed via the v1.1.0 extension.

## Outstanding follow-ups

1. ~~**Thread 2 follow-up amendment**~~ — **CLOSED in v1.1.0** via
   commit `ac40ca1` (Wave 3 ledger #2 extension: consuming-self with
   own generic params). The pattern-based exemption per the
   recommendation: when a function declares `consuming`/`borrowing`
   modifier AND has its own generic parameter clause, treat as
   method-scoped (not type-scoped). 3 new tests added; 16 tests
   total in the ExtensionNoncopyableConstraint suite, all pass.

2. ~~**swift-standard-library-extensions Lint sub-package build defect**~~
   — **CLOSED in v1.1.0** via commit `02ac34f` in
   swift-primitives/swift-standard-library-extensions. Added direct
   `swift-institute-linter-rules` package dep + `Linter Rule Naming`
   product dep + `internal import Linter_Rule_Naming` to main.swift.
   Build clean; lint runs to completion at 0 findings.

3. **Visibility-tagged lint pass** (per Thread 4 research doc empirical
   follow-up) — extend the lint pass to capture visibility per
   finding to measure the fileprivate/private slice ecosystem-wide.
   Informs the [API-NAME-002] private-surface decision.

4. **`nonisolated(unsafe)` site enumeration** (per Thread 7 research
   doc empirical follow-up) — extend the lint pass to count
   `nonisolated(unsafe)` sites + `@safe` adjacency rate ecosystem-
   wide. Informs the [MEM-SAFE-025] migration plan's scope.

## Closeout

Wave 3 dispatch is functionally complete. The aggregate validation
confirms:

- Predicted compound-identifier finding drop materialized (via engine
  DocC exclusion + Wave 2 source-fixes + Wave 3 #3 exemption).
- All Wave 3 rule amendments hold in the aggregate (no surprise
  regressions).
- Residual residuals are mapped to known policy/decision/design
  workstreams; one is a Thread 2 partial-gap with a clear follow-up
  amendment path.

## References

- Pre-amendment baseline: [lint-pass-2026-05-11-aggregate.md](lint-pass-2026-05-11-aggregate.md)
- Wave 2 dispatch ledger: [wave-2-rule-amendments-2026-05-11.md](wave-2-rule-amendments-2026-05-11.md)
- Wave 3 dispatch source: `HANDOFF.md` (Wave 3 rule-amendment backlog + queued policy decisions)
- Wave 2 leaf triage commits: swift-ownership-primitives `b475d6f`, swift-standard-library-extensions `d19e725`, swift-institute/Scripts `54c55d9`
- Wave 3 ledger commits (rule amendments):
  - swift-linter-rules: `f89c4d4` (#1), `4f85e1a` (#2), `d18e62a` (#5 — InlinableInternalAccess), `ac40ca1` (#2 extension: consuming-self with own generic params)
  - swift-institute-linter-rules: `02cab07` (#3), `686f208` (#4 — BoxClass)
- Wave 3 thread #9 follow-ups (v1.1.0):
  - swift-primitives/swift-standard-library-extensions: `02ac34f` (Lint sub-package build fix)
  - swift-linter-rules: `ac40ca1` (Thread 2 extension)
- Wave 3 research docs (RECOMMENDATION, pending decision):
  - `swift-institute/Research/api-name-002-private-surface-applicability.md` (Thread #4)
  - `swift-institute/Research/mem-safe-025-reconciliation.md` (Thread #7)
  - `swift-institute/Research/swift-linter-per-finding-disable-mechanism.md` (Thread #8)
