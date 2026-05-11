// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-linter-rules open source project
//
// Copyright (c) 2026 Coen ten Thije Boonkkamp and the swift-linter-rules project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

public import Linter_Primitives
internal import SwiftSyntax

/// Wave 3 (mechanization-program) — namespace-bridging typealias that
/// preserves the leaf name silently re-points new nested-type
/// declarations to a foreign module's namespace.
///
/// Citation: `[PLAT-ARCH-018]` (platform skill — typealiased namespace-
/// path conflict rule).
///
/// When `extension A { public typealias Kernel = Kernel_Primitives_Core.Kernel }`
/// is in effect, declaring `extension A.Kernel.Descriptor { ... }`
/// resolves to `Kernel_Primitives_Core.Kernel.Descriptor` at compile
/// time, NOT `A.Kernel.Descriptor`. New-type declarations at this
/// path silently CONFLICT with any existing type at the foreign-module
/// path. Source-level readers see "A's Descriptor"; the compiler sees
/// "foreign-module's Descriptor."
///
/// AST shape: detect typealias declarations whose LHS name matches the
/// RHS member-type leaf name. Walk `TypeAliasDeclSyntax` whose
/// `initializer.value` is a `MemberTypeSyntax` and whose `.name.text`
/// equals the typealias's own `.name.text`. This is the canonical
/// "namespace-bridging" shape; flag with a reminder to grep the foreign
/// module before declaring new sub-types via this aliased path.
///
/// Worked examples (flagged):
///   - `extension ISO_9945 { public typealias Kernel = Kernel_Primitives_Core.Kernel }`
///     — `Kernel = ….Kernel`; aliased namespace path now points to a
///     foreign module.
///   - `extension POSIX { typealias Socket = Foundation.Socket }` —
///     same shape across any modules.
///
/// Worked examples (NOT flagged):
///   - `typealias Storage = Internal.Buffer` — RHS leaf (`Buffer`) ≠ LHS
///     (`Storage`); typealias is a rename, not a namespace bridge.
///   - `typealias Foo = Int` — RHS is a plain identifier, no member
///     chain to bridge.
///   - `typealias Error = Async.Lifecycle.Error` — RHS leaf matches but
///     covered by `[API-ERR-008]` (different rule); leaving in the
///     diagnostic for [PLAT-ARCH-018] is acceptable as the namespace-
///     conflict concern applies here too.
extension Lint.Rule.Platform {
    public struct TypealiasedNamespace: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "typealiased_namespace_bridge"
        public static let defaultSeverity: Diagnostic.Severity = .warning

        public let severity: Diagnostic.Severity

        @inlinable
        public init(severity: Diagnostic.Severity = .warning) {
            self.severity = severity
        }

        public func findings(in source: Lint.Source.Parsed) -> [Diagnostic.Record] {
            let visitor = Visitor(source: source.file, severity: severity, converter: source.converter)
            visitor.walk(source.tree)
            return visitor.matches
        }
    }
}

extension Lint.Rule.Platform.TypealiasedNamespace {
    @usableFromInline
    static let message: Swift.String =
        "[typealiased_namespace_bridge] [PLAT-ARCH-018]: typealias whose "
        + "LHS name matches its RHS member-type leaf silently bridges a "
        + "foreign namespace into the local one. New-type declarations at "
        + "`<local>.<aliased>.<NewName>` resolve to the foreign module — "
        + "any existing type at the same foreign path conflicts silently. "
        + "Before adding sub-types via this aliased path, grep the foreign "
        + "module for collisions and choose a non-conflicting sub-path, a "
        + "non-typealiased namespace entry, or relocate the foreign type."

    final class Visitor: SyntaxVisitor {
        let source: Source.File
        let severity: Diagnostic.Severity
        let converter: SourceLocationConverter
        var matches: [Diagnostic.Record] = []

        init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
            self.source = source
            self.severity = severity
            self.converter = converter
            super.init(viewMode: .sourceAccurate)
        }

        override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
            let aliasName = node.name.text
            guard let member = node.initializer.value.as(MemberTypeSyntax.self) else {
                return .visitChildren
            }
            guard member.name.text == aliasName else { return .visitChildren }
            let location = converter.location(for: node.name.positionAfterSkippingLeadingTrivia)
            matches.append(Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: Lint.Rule.Platform.TypealiasedNamespace.id.underlying,
                message: Lint.Rule.Platform.TypealiasedNamespace.message
            ))
            return .visitChildren
        }
    }
}
