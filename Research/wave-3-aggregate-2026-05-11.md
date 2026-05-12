# Wave 3 Aggregate — Post-Amendment Validation

<!--
---
version: 1.3.0
last_updated: 2026-05-12
status: IMPLEMENTED
---
-->

## Changelog

- **v1.3.0 (2026-05-12)** — Post-closure empirical follow-ups (Phase 1.4
  of the post-Wave-3 quick-wins dispatch):
  - Open Follow-Up #4 answered — `nonisolated(unsafe)` site enumeration
    ecosystem-wide: **28 occurrences across 20 files in production
    Sources** (24 real + 4 in-rule token references). Workspace-wide
    grep against `swift-primitives/*/Sources`, `swift-foundations/*/Sources`,
    `swift-standards/*/Sources` 2026-05-12. `@safe`-on-same-line adjacency
    rate: 0. Structural adjacency via enclosing-type `@safe` (absorber
    pattern): observed, not enumerated per-site.
  - Open Follow-Up #5 scope refined — Wave 4's absorber-pattern footprint
    is **~128 sites, not ~80**. Empirical count: 140 `@safe` occurrences
    in 125 files, of which ~128 attach to type-decls (absorber pattern)
    and ~22 attach to individual decls (direct). Hot-spot packages
    enumerated in Open Follow-Up #5 entry. Wave 4 dispatch sizing should
    use 128, not 80.
  - No engine / rule / Skills changes in v1.3.0 — empirical refinement
    of Open Follow-Ups only.
- **v1.2.0 (2026-05-12)** — Wave 3 fully closed:
  - All 3 user-tier policy decisions stamped DECISION (Options B, B, D) at swift-institute/Research stamp commit `78f9bea` (after the 3 RECOMMENDATION docs `59f3906`, `5e2b1c5`, `c3dfd92`).
  - **Thread 4 implemented** — [API-NAME-002] amended for fileprivate+private exemption. Skills `3a36ce3` + swift-institute-linter-rules `1c06647`. Visibility check walks the parent chain for effective visibility (the simple-modifier sketch in the research doc was insufficient — `Header` fields had no explicit modifier; visibility came from enclosing fileprivate struct). 15 new tests; 182 total pass. 2 Header.* residuals close (in-test verified via verbatim regression test).
  - **Thread 7 implemented** — [MEM-SAFE-025] split into [MEM-SAFE-025a] (invariant comment) + [MEM-SAFE-025b] (@safe forbidden in Sources). Skills `677ccaa` + swift-linter-rules `8e06283` (delete NonisolatedUnsafeSafe + create NonisolatedUnsafeInvariant + SafeForbidden + 20 new tests). 5-package source migration: swift-render-primitives `c205917`, swift-machine-primitives `063a6e1`, swift-witnesses `b241dc5`, swift-cpu-primitives `2eaf579`, swift-memory-primitives `56bd0f6`. The 4 AMBIGUOUS residuals (3 on swift-ownership-primitives + 1 on swift-property-primitives) close vacuously — neither package has any `nonisolated(unsafe)` decls in Sources (the doc-enumerated reference to "3 nonisolated(unsafe) AMBIGUOUS findings" was misattributed).
  - **Thread 8 implemented** — per-finding disable mechanism via Option D hybrid. Engine commit swift-linter `f913d1b` (line-comment scan + suppression map; ~314 LOC). Config-file thread via swift-linter-primitives `d15e030` (Manifest.disabledRuleIDs → Driver → Configuration, previously silently ignored post-Phase-B.1 decouple). Rule message updates swift-linter-rules `2d5dc2f` (6 rules: unchecked call site, enumerated with subscript, count minus one, zero or one literal, for loop in result builder, raw value access). Slot.Move sites suppressed in swift-ownership-primitives `cbce2cd`. 24/24 tests pass. 2 unchecked-call-site residuals close.
  - **Per-target residual count: 12 → 4.** The 4 remaining are all `takeIfPresent` / `consumeIfStored` compound-name findings on `swift-ownership-primitives` (HANDOFF Open Q3) — breaking-API rename deferred until next API-design pass.
  - **New scope surfaced (Wave 4):** Thread 7's `SafeForbidden` rule fires on ~80 `@safe` absorber-pattern sites ecosystem-wide ([MEM-SAFE-021]/[MEM-SAFE-022]/[MEM-SAFE-023]). [MEM-SAFE-025b] body explicitly names this as out-of-scope for Wave 3. Future dispatch options: (a) extend [MEM-SAFE-025b] with absorber-pattern carve-out, (b) migrate all ~80 sites, or (c) introduce a `@unsafe` escape hatch via Thread 8's `// swift-linter:disable` directive.
  - **Pre-existing test failures closed** (orthogonal to Wave 3 but flagged by Thread 7/8 subagents; closure included in this ledger for completeness):
    - swift-machine-primitives `Machine.Node Tests:252` — Tagged API rename `.rawValue` → `.underlying` not propagated to test (`8695ce4`).
    - swift-witnesses `@Witness` macro — `__unchecked` → `_unchecked` init-label cascade missed from 2026-05-04 finite-primitives migration (`3556323`).
    - swift-linter-rules `MockFactoryZeroCollision Tests` — test fixture default path `Sources/X/Test.swift` didn't satisfy Wave 2 amendment #10's `/Tests/` scope gate; fixture corrected to `/Tests/X/Test.swift` (`40608cb`). Root cause was fixture drift, not rule logic drift.
  - **Engine on main**: swift-linter ff-merged `lint-pass-audit-2026-05-11` into `main` (THROWAWAY `17a9777` survives in history per user "will be squashed later before publication"); feature branch deleted.
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

**Engine (v1.2.0)**: swift-linter @ `f913d1b` on `main` (post-ff-merge):
- `b060fb3` Three-tier hierarchy: drop rule deps; hoist Lint.run() helper (pre-Wave-3)
- `86856c1` Exclude `*.docc/**` from source discovery; add path-substring safety net (pre-Wave-3)
- `f913d1b` Wave 3 Thread 8: add per-finding disable mechanism (line-comment + config-file)

**Rule packages (v1.2.0)**:
- swift-linter-rules @ `40608cb` — includes Wave 3 #1, #2, #2-ext, #5, #6, #7 split (NonisolatedUnsafeInvariant + SafeForbidden), #8 rule-message updates, and MockFactoryZeroCollision fixture-path fix
- swift-institute-linter-rules @ `1c06647` — includes Wave 3 #3, #4 (BoxClass), #4-amend (visibility check)
- swift-linter-primitives @ `d15e030` — Wave 3 #8 Lint.Configuration.disabledRuleIDs
- swift-institute/Skills @ `677ccaa` — Wave 3 #4 [API-NAME-002] amendment + #7 [MEM-SAFE-025] split

**Lint executable build**: per-package `Lint/` nested sub-package; path-
deps onto rule packages pick up Wave 3 amendments locally without
`swift package update`.

## Per-target totals

| Target | Baseline | Wave 3 v1.1.0 | Wave 3 v1.2.0 | Δ | Notes |
|--------|---------:|--------------:|--------------:|---:|------|
| swift-carrier-primitives | 18 | 0 | 0 | -18 | DocC findings cleared via engine exclusion (86856c1); MEM-COPY + minimal Protocol closed by Wave 2 ledger entries |
| swift-comparison-primitives | 45 | 0 | 0 | -45 | DocC + Wave 2 closeouts |
| swift-either-primitives | 6 | 0 | 0 | -6 | Compound `flatMap` exempted via stdlib-idiom citations (Wave 2 ledger #1) |
| swift-equation-primitives | 55 | 0 | 0 | -55 | DocC + Wave 2 closeouts |
| swift-hash-primitives | 46 | 0 | 0 | -46 | DocC + Wave 2 closeouts |
| swift-ownership-primitives | 56 | 11 | 4 | -52 | v1.2.0: Thread 4 closes 2 Header.* (private surface); Thread 7 closes 3 nonisolated-unsafe vacuously (no sites in Sources); Thread 8 closes 2 unchecked-call-site (suppressed at Slot.Move). 4 takeIfPresent/consumeIfStored compound-name remain (HANDOFF Open Q3, breaking-API rename deferred) |
| swift-product-primitives | 13 | 0 | 0 | -13 | MEM-COPY pack-expansion + Existential — Wave 2 ledger amendments |
| swift-property-primitives | 15 | 1 | 0 | -15 | v1.2.0: Thread 7 closes the 1 AMBIGUOUS vacuously (no nonisolated(unsafe) in Sources) |
| swift-standard-library-extensions | 620 | 0 | 0 | -620 | v1.1.0: Lint sub-package build defect fixed (`02ac34f`); re-ran clean. All 620 baseline findings closed via combined engine DocC exclusion + Wave 2 source-fixes (d19e725) + `.disable(.\`int public parameter\`)` directive (54) + Wave 3 amendments |
| swift-tagged-primitives | 22 | 0 | 0 | -22 | Tagged-init + bridge + Compound closeouts |
| **Total (11 packages)** | **896** | **12** | **4** | **-892** | **99.6% drop ecosystem-wide; 4 takeIfPresent residuals deferred (HANDOFF Open Q3)** |

**Wave 4 emergence (out-of-scope for this ledger; tracked separately):**
Thread 7's new `SafeForbidden` rule fires on ~80 `@safe` absorber-pattern
sites ecosystem-wide ([MEM-SAFE-021]/[MEM-SAFE-022]/[MEM-SAFE-023]).
These sites are NOT counted in the per-target totals above (the
ledger scope is the original Wave 3 residual). Wave 4 dispatch will
need its own ledger.

The 263-finding drop on the 9 cleanly-building packages confirms the
handoff's prediction ("compound identifier findings drop materially
due to local-var scope gate; docc findings clear via engine
exclusion"). The compound_identifier rule's 363 baseline findings
were dominated by DocC step-files (the per-leaf reports cited
`Carrier Primitives.docc/Resources/step-*` paths as the bulk); the
engine's `*.docc/**` exclusion (`86856c1`, landed pre-Wave-3 but
post-baseline) removes those without rule changes.

## Per-rule breakdown of remaining 4 findings (v1.2.0)

All 4 residuals are in swift-ownership-primitives. All are
`compound identifier` findings on `takeIfPresent` / `consumeIfStored`
APIs deferred per HANDOFF Open Q3 (breaking-API rename held for next
API-design pass).

### swift-ownership-primitives — 4 findings

| Rule | Count | Disposition |
|------|------:|-------------|
| compound identifier | 4 | `takeIfPresent` / `consumeIfStored` × 4 on `Slot.Move` + retained-incoming/outgoing — API-rename decision deferred per HANDOFF Open Q3 (compound-name exception vs `take.ifPresent` nested-accessor refactor; breaking API for 4 call sites) |
| ~~compound identifier (Header)~~ | ~~2~~ | **CLOSED in v1.2.0** via Thread 4 (`1c06647`) — fileprivate/private exemption added to [API-NAME-002]; `destroyPayload` / `payloadOffset` on `Erased.Outgoing.Header` no longer flagged |
| ~~unchecked sendable noncopyable~~ | ~~3~~ | **CLOSED in v1.2.0** vacuously via Thread 7 (`8e06283` + skill split `677ccaa`) — no `nonisolated(unsafe)` decls in swift-ownership-primitives Sources; the AMBIGUOUS findings predicate doesn't apply under the new [MEM-SAFE-025a] (invariant comment) + [MEM-SAFE-025b] (@safe forbidden) split |
| ~~unchecked call site~~ | ~~2~~ | **CLOSED in v1.2.0** via Thread 8 (`f913d1b` engine + `cbce2cd` source) — `Slot.Move.in/out` suppressed with `// swift-linter:disable:next unchecked call site` + `// REASON:` citing [CONV-016] |
| ~~extension noncopyable constraint~~ | ~~1~~ | **CLOSED in v1.1.0** via Thread 2 extension (`ac40ca1`) |

### swift-property-primitives — 0 findings (v1.2.0)

| Rule | Count | Disposition |
|------|------:|-------------|
| ~~unchecked sendable categorization~~ | ~~1~~ | **CLOSED in v1.2.0** vacuously via Thread 7 — no `nonisolated(unsafe)` decls in Sources |

## Wave 3 thread-by-thread validation

| Thread | Wave 3 deliverable | Baseline finding | Post-amendment | Result |
|--------|--------------------|------------------|----------------|--------|
| #1 — ExtensionNoncopyableConstraint nested-type skip | Code amendment (f89c4d4) + 3 tests | 6 RULE-WRONG | 0 of these 6 remain | ✓ Closed |
| #2 — ExtensionNoncopyableConstraint method-local generics | Code amendment (4f85e1a) + 4 tests; **v1.1.0 extension** `ac40ca1` adds consuming-self/own-generics exemption + 3 tests | 1 RULE-WRONG | 0 of these remain (both parameter-shape AND consuming-self shape now exempt) | ✓ Closed (v1.1.0) |
| #3 — NamingCompound SE-0517 mutableSpan/span exemption | Code amendment (02cab07) + 2 tests | 1 RULE-WRONG | 0 of this 1 remains | ✓ Closed |
| #4 — NamingCompound private-surface policy | Research doc + DECISION (Option B) `78f9bea` + Skills `3a36ce3` + rule amendment `1c06647` (visibility helper walks parent chain for effective visibility) | 2 RULE-WRONG (held) | 0 remain | ✓ Closed (v1.2.0) |
| #5 — BoxClass canonical-CoW-backing exemption | Code amendment (686f208) + 4 tests | 1 RULE-WRONG (ad_hoc_box_class on Indirect.Storage) | 0 of this 1 remains | ✓ Closed |
| #6 — InlinableInternalAccess init-specific message | Code amendment (d18e62a) + 3 tests | 0 (Wave 2 source-fix already closed) | n/a — message-quality amendment, not a finding-count amendment | ✓ Closed (consumer-experience improvement) |
| #7 — [MEM-SAFE-025] reconciliation | Research doc + DECISION (Option B) `78f9bea` + Skills split `677ccaa` + rule split `8e06283` (NonisolatedUnsafeSafe → NonisolatedUnsafeInvariant + SafeForbidden) + 5-package source migration (`c205917`, `063a6e1`, `b241dc5`, `2eaf579`, `56bd0f6`) | 3 unchecked-sendable-noncopyable + 1 AMBIGUOUS (held) | 0 remain (closed vacuously — no nonisolated(unsafe) in Sources of ownership/property primitives) | ✓ Closed (v1.2.0); ~80 absorber-pattern sites surfaced → Wave 4 |
| #8 — Per-finding disable mechanism | Research doc + DECISION (Option D) `78f9bea` + engine `f913d1b` (line-comment + suppression map) + Configuration thread `d15e030` + rule-message updates `2d5dc2f` + source migration `cbce2cd` | 2 unchecked-call-site (held) | 0 remain (Slot.Move.in/out suppressed with REASON citing [CONV-016]) | ✓ Closed (v1.2.0) |

## Wave 3 amendment summary

- **5 rule amendments landed in v1.0.0** (Threads #1, #2, #3, #5, #6) across 2 rule packages, 12 new tests added.
- **1 rule amendment + 1 follow-up landed in v1.1.0** (Thread 2 extension `ac40ca1` + stdlib-extensions build fix `02ac34f`).
- **3 user-tier-decision implementations landed in v1.2.0** (Threads #4, #7, #8): 1 [API-NAME-002] amendment + 1 [MEM-SAFE-025] split (2-rule replacement) + 1 engine extension (per-finding disable). 59 new tests added (15 + 20 + 24). 4 user-tier-decision-blocked rule classes close.
- **3 pre-existing test failures closed in v1.2.0** (orthogonal to Wave 3): machine-primitives Tagged API drift, witnesses macro init-label cascade, MockFactoryZeroCollision fixture path.
- **892 finding drop** ecosystem-wide (v1.2.0 11-package number: 896 → 4; 99.6%).

## Residuals after Wave 3 (v1.2.0)

The 4 remaining findings are all in one rule class:

- **4 API-rename decisions** (HANDOFF Open Q3: takeIfPresent / consumeIfStored rename to nested accessor; breaking API for 4 call sites)

The Wave 3 dispatch is **fully closed**. Every original residual is
either resolved (8 of 12) or mapped to the deferred API-rename pass
(4 of 12). The v1.0.0 Thread 2 partial-gap closed in v1.1.0.

**Wave 4 carry-forward**: Thread 7's new `SafeForbidden` rule fires on
~80 `@safe` absorber-pattern sites ecosystem-wide ([MEM-SAFE-021] /
[MEM-SAFE-022] / [MEM-SAFE-023]). These sites are NOT in this
ledger's per-target scope — they emerged from a rule whose previous
form ([MEM-SAFE-025] requires `@safe`) actually MANDATED the pattern
that the new form forbids. The ~80-site footprint informs Wave 4
dispatch: extend [MEM-SAFE-025b] with absorber-pattern carve-out, or
migrate all sites, or apply Thread 8's `// swift-linter:disable`
directive site-by-site.

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
   The v1.2.0 amendment ships without this empirical measurement;
   would inform a future tightening pass.

4. **`nonisolated(unsafe)` site enumeration** (per Thread 7 research
   doc empirical follow-up) — **answered 2026-05-12** via workspace-wide
   grep across `swift-primitives/*/Sources`, `swift-foundations/*/Sources`,
   `swift-standards/*/Sources`. Total: **28 occurrences across 20 files
   in production Sources** (24 real + 4 in-rule token references inside
   `Lint.Rule.Memory.NonisolatedUnsafeInvariant.swift` / `Lint.Rule.Memory.SafeForbidden.swift`).
   `@safe`-on-same-line adjacency: 0 sites. Structural adjacency via
   enclosing-type `@safe` (absorber pattern): observed e.g.
   `swift-darwin-standard/Darwin.Loader.Image.Header.swift:31` where
   `nonisolated(unsafe) let rawValue` lives inside a `@safe public struct Header`.

5. **Wave 4 absorber-pattern dispatch** — Thread 7 surfaced **~128 `@safe`
   absorber-pattern sites** (NOT the initial ~80 estimate) — empirical
   count 2026-05-12 across the same Sources/ scope: **140 `@safe`
   occurrences total** (125 distinct files), of which **~128 attach to
   type-decls (struct/class/enum/actor/extension/protocol)** (absorber
   pattern) and **~22 attach to individual decls** (func/var/let/init/
   subscript/typealias) (direct). Top packages by absorber-pattern
   density: `swift-bit-vector-primitives` (17), `swift-ownership-primitives`
   (14), `swift-machine-primitives` (9), `swift-buffer-primitives` (8),
   `swift-queue-primitives` (7), `swift-property-primitives` (7),
   `swift-memory-primitives` (6). Needs its own ledger + policy decision
   (carve-out / migrate / disable-directive). [MEM-SAFE-025b] body
   explicitly names this as Wave 3's out-of-scope follow-up. Scope is
   60% larger than initial estimate — Wave 4 dispatch sizing should
   reflect the ~128 figure, not ~80.

6. **takeIfPresent / consumeIfStored API-rename pass** (HANDOFF Open
   Q3) — accept compound-name exception OR refactor to
   `take.ifPresent` nested accessor (breaking API for 4 call sites
   on `Slot.Move` retained-incoming/outgoing). Hold for next
   API-design cycle.

## Closeout

Wave 3 dispatch is **fully closed (v1.2.0)**. The aggregate validation
confirms:

- Predicted compound-identifier finding drop materialized.
- All Wave 3 rule amendments hold in the aggregate (no surprise
  regressions).
- All three user-tier policy decisions stamped, implemented, and
  validated.
- 8 of 12 residuals closed via implementation; 4 deferred to the next
  API-design cycle.
- A new scope (Wave 4: `@safe` absorber-pattern, ~80 sites) surfaced
  as a consequence of Thread 7's two-rule replacement and is tracked
  as a separate dispatch.

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
- Wave 3 v1.2.0 implementation commits (user-tier decisions):
  - swift-institute/Research: `59f3906`, `5e2b1c5`, `c3dfd92` (RECOMMENDATION docs) + `78f9bea` (stamp DECISION Options B/B/D)
  - Thread #4 (Option B — fileprivate/private exemption):
    - swift-institute/Skills: `3a36ce3` ([API-NAME-002] visibility-scope sub-section)
    - swift-institute-linter-rules: `1c06647` (Lint.Rule.Naming.Compound visibility helper + 15 tests)
  - Thread #7 (Option B — two-rule replacement):
    - swift-institute/Skills: `677ccaa` ([MEM-SAFE-025] SUPERSEDED + [MEM-SAFE-025a/b])
    - swift-linter-rules: `8e06283` (NonisolatedUnsafeInvariant + SafeForbidden, 20 tests)
    - swift-render-primitives: `c205917` (Thunk/Work @safe → SAFETY)
    - swift-machine-primitives: `063a6e1` (Value/Capture.Slot _Storage @safe → SAFETY)
    - swift-foundations/swift-witnesses: `b241dc5` (Values._Storage @safe → SAFETY)
    - swift-cpu-primitives: `2eaf579` (CPU.Cache.Padded @safe → SAFETY)
    - swift-memory-primitives: `56bd0f6` (DocC examples updated)
  - Thread #8 (Option D — hybrid line-comment + config-file):
    - swift-linter: `f913d1b` (Lint.Suppression + Lint.Run elision + Driver threading)
    - swift-linter-primitives: `d15e030` (Lint.Configuration.disabledRuleIDs)
    - swift-linter-rules: `2d5dc2f` (6 rule messages updated; natural-English IDs)
    - swift-ownership-primitives: `cbce2cd` (Slot.Move.in/out suppressed per [CONV-016])
- Wave 3 v1.2.0 pre-existing test fixes (orthogonal cleanup):
  - swift-machine-primitives: `8695ce4` (Tagged `.rawValue` → `.underlying`)
  - swift-foundations/swift-witnesses: `3556323` (@Witness macro `__unchecked` → `_unchecked` cascade)
  - swift-linter-rules: `40608cb` (MockFactoryZeroCollision test fixture path `/Tests/`)
- Wave 3 research docs (DECISION, v1.2.0):
  - `swift-institute/Research/api-name-002-private-surface-applicability.md` (Thread #4, Option B)
  - `swift-institute/Research/mem-safe-025-reconciliation.md` (Thread #7, Option B)
  - `swift-institute/Research/swift-linter-per-finding-disable-mechanism.md` (Thread #8, Option D)
