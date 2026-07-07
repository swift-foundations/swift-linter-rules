// Phase 4 wave-1 integration fixture — one violation per new rule.
// The linter run against this file must fire exactly 7 diagnostics.
//
// swiftlint:disable no_existential_throws no_impl_obj_inst_bindings options_not_flags swift_error_qualification
// REASON: this fixture's entire purpose is to contain exactly one violation per rule under
// test (self-referential fixture shape, rule-exemptions skill) — the parent SwiftLint config's
// institute rule bundle also lints this repo's own sources and flags the same patterns this
// file deliberately embeds for the Phase 4 wave-1 integration run.

// 1. `try optional` — `try?` swallows the typed error
let result1 = try? throwingCall()

// 2. `untyped throws` — bare `throws` erases the error type
func bare() throws -> Int { 0 }

// 3. `existential throws` — `throws(any Error)` is existential
func existential() throws(any Error) -> Int { 0 }

// 4. `variable named impl` — local bound as `impl`
func setup() {
    let impl = factory()
    _ = impl
}

// 5. `property named flags` — OptionSet type with `Flags` suffix
struct DebugFlags: OptionSet {
    let rawValue: Int
}

// 6. `compound identifier` — verb-noun camelCase method name
func openWrite() {}

// 7. `tag suffix` — phantom-type marker named with `Tag` suffix
struct CardinalTag {}
// swiftlint:enable no_existential_throws no_impl_obj_inst_bindings options_not_flags swift_error_qualification
