// Phase 4 wave-1 integration fixture — one violation per new rule.
// The linter run against this file must fire exactly 7 diagnostics.

// 1. try_optional — `try?` swallows the typed error
let result1 = try? throwingCall()

// 2. untyped_throws — bare `throws` erases the error type
func bare() throws -> Int { 0 }

// 3. existential_throws — `throws(any Error)` is existential
func existential() throws(any Error) -> Int { 0 }

// 4. var_named_impl — local bound as `impl`
func setup() {
    let impl = factory()
    _ = impl
}

// 5. option_named_flags — OptionSet type with `Flags` suffix
struct DebugFlags: OptionSet {
    let rawValue: Int
}

// 6. compound_identifier — verb-noun camelCase method name
func openWrite() {}

// 7. tag_suffix — phantom-type marker named with `Tag` suffix
struct CardinalTag {}
