# swift-linter-rules

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

Catalog of SwiftSyntax-based AST lint rules consumable by
[`swift-linter`](https://github.com/swift-foundations/swift-linter) or any
third-party tool that imports the `Linter Primitives` protocol surface.
Each rule ships as its own SwiftPM library product so consumers activate
exactly the rules they want.

## Quick Start

In your `Lint/` nested SwiftPM package (per `swift-linter`'s adoption
recipe), depend on this package and import the rule packs you want
active:

```swift
// Lint/Package.swift
.package(url: "https://github.com/swift-foundations/swift-linter-rules.git", from: "0.1.0"),
```

```swift
// Lint/Sources/Lint/main.swift
import Linter
import Linter_Rule_Unchecked
import Linter_Rule_Cardinal

let manifest = Lint.Manifest(
    enabledRuleIDs: [
        Lint.Rule.Unchecked.id,
        Lint.Rule.Cardinal.Count.id,
    ]
)
```

`swift run swift-linter <package>` builds the `Lint/` package and runs
the activated rules against your sources.

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/swift-foundations/swift-linter-rules.git", from: "0.1.0"),
]
```

```swift
.target(
    name: "Lint",
    dependencies: [
        .product(name: "Linter Rule Cardinal", package: "swift-linter-rules"),
        // ... additional rule pack products
    ]
)
```

## Rule catalog

Each pack ships as its own SwiftPM product. Activate per-rule via the
`Lint.Manifest`'s `enabledRuleIDs` list.

| Pack product | Rule ID | What it catches |
|---|---|---|
| `Linter Rule Unchecked` | `unchecked_call_site` | `__unchecked:` argument labels at call sites that bypass the typed-system contract |
| `Linter Rule Cardinal` | `cardinal_zero_one_constructor` | `Cardinal(0)` / `Cardinal(1)` constructor calls (use the typed `.zero` / `.one` accessors instead) |
| `Linter Rule Cardinal` | `cardinal_count_minus_one` | `count - 1` and its semantically-equivalent rewrites — operand-reorder, paren-wrap, cast-outside |
| `Linter Rule RawValue` | `chained_rawvalue_access` | Chained `.rawValue.method()` patterns that escape the typed wrapper |
| `Linter Rule RawValue` | `bitpattern_rawvalue_chain` | Bit-pattern conversions chaining `.rawValue` |
| `Linter Rule ResultBuilder` | `result_builder_for_loop` | `for i in 0..<N { i }` style integer loops in builder bodies |
| `Linter Rule Try Optional` | `try_optional` | `try?` sites that swallow typed-throws errors silently |
| `Linter Rule Untyped Throws` | `untyped_throws` | `throws` declarations without a typed-throws clause |
| `Linter Rule Existential Throws` | `existential_throws` | `throws(any Error)` existential-error declarations |
| `Linter Rule Var Named Impl` | `var_named_impl` | Local bindings named `impl` (use the type's own name) |
| `Linter Rule Option Named Flags` | `option_named_flags` | `OptionSet` types named `*.Flags` (use `*.Options`) |
| `Linter Rule Compound Identifier` | `compound_identifier` | Compound type, method, or property names that should decompose into nested forms |
| `Linter Rule Tag Suffix` | `tag_suffix` | Phantom-type tags suffixed with `Tag` (use the bare concept name) |

Each rule's source carries inline documentation describing its AST
predicate, the source patterns it covers, and the convention it enforces.

## Authoring third-party rule packs

Every rule pack — institute-canonical or third-party — implements the
same protocol surface from
[`swift-linter-primitives`](https://github.com/swift-primitives/swift-linter-primitives).
A minimal third-party rule pack is one library product with a type
conforming to `Lint.Rule.Protocol`:

```swift
// Sources/MyRule/MyRule.swift
public import Linter_Primitives
internal import SwiftSyntax

extension Lint.Rule {
    public struct MyRule: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "my_rule"
        public static let defaultSeverity: Diagnostic.Severity = .warning

        public let severity: Diagnostic.Severity

        public init(severity: Diagnostic.Severity = .warning) {
            self.severity = severity
        }

        public func findings(in source: Lint.Source.Parsed) -> [Lint.Finding] {
            // Walk the AST, return findings for matching sites.
            return []
        }
    }
}
```

Consumers depend on your package alongside `swift-linter-rules` and
import your rule pack the same way:

```swift
// Lint/Sources/Lint/main.swift
import Linter
import Linter_Rule_Cardinal       // institute-canonical pack
import MyRule                      // third-party pack

let manifest = Lint.Manifest(
    enabledRuleIDs: [
        Lint.Rule.Cardinal.Count.id,
        Lint.Rule.MyRule.id,
    ]
)
```

The `swift-linter` driver makes no distinction between canonical and
third-party packs — both flow through the same `Lint.Manifest`
activation mechanism.

## Consumers

- [`swift-linter`](https://github.com/swift-foundations/swift-linter) —
  the CLI driver and reporter shell.
- Any third-party tooling that wants the same rule predicates without the
  swift-linter executable (the predicates are pure functions over a
  `SourceFileSyntax`).

## License

Apache 2.0. See [LICENSE.md](LICENSE.md).
