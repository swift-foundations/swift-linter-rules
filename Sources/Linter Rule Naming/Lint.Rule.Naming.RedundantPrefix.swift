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

/// Wave 1 (mechanization-program) — redundant-prefix declaration names.
///
/// Citation: `[API-NAME-013]` (code-surface skill — Drop Redundant Prefix).
///
/// When a declaration is named `<Prefix><Suffix>` and is nested inside
/// a parent type or extension whose name is `<Prefix>`, the `<Prefix>`
/// is redundant — the containing type IS the missing context. Examples
/// caught by this rule:
///
///   - `enum Walk { struct WalkOptions {} }` — `WalkOptions` should be
///     `Options` (parent already says "Walk").
///   - `enum File { enum FileError {} }` — `FileError` should be `Error`.
///   - `extension Manifest { struct ManifestEntry {} }` — `ManifestEntry`
///     should be `Entry`.
///
/// Detection: the decl's name starts with the enclosing type's name AND
/// has additional characters after the prefix (`Walk` matched against
/// `Walk` does NOT fire; `WalkOptions` matched against `Walk` fires).
/// The enclosing name is the immediate parent's identifier — for an
/// `ExtensionDeclSyntax`, the LAST component of the extended type
/// expression (`extension A.B.C { ... }` → enclosing = `C`).
///
/// Worked examples (flagged):
///   - `enum Walk { struct WalkOptions {} }` → `WalkOptions` flagged.
///   - `extension File { enum FileError {} }` → `FileError` flagged.
///   - `struct Manifest { struct ManifestEntry {} }` → flagged.
///
/// Worked examples (NOT flagged):
///   - `enum Walk { struct Options {} }` → bare `Options`, no redundancy.
///   - `enum Walk {}` (top-level, no enclosing) → no parent to compare.
///   - `enum Foo { struct FooBar {} }` IS flagged (FooBar's prefix Foo matches).
///   - `enum Foo { struct Foo {} }` is NOT flagged (exact match, not a
///     compound — the inner `Foo` is just `Foo`, not `Foo<Suffix>`).
///
/// This rule complements `Lint.Rule.Naming.CompoundType` ([API-NAME-001]):
/// CompoundType flags compound names regardless of context; this rule
/// flags compound names whose prefix is structurally redundant given
/// the enclosing namespace.
extension Lint.Rule.Naming {
    public struct RedundantPrefix: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "redundant_prefix"
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

extension Lint.Rule.Naming.RedundantPrefix {
    @usableFromInline
    static let message: Swift.String =
        "[redundant_prefix] [API-NAME-013]: nested declaration name has a "
        + "redundant prefix that matches the enclosing namespace. Drop the "
        + "prefix — the containing type already supplies the context. "
        + "Example: `enum Walk { struct Options {} }` not "
        + "`enum Walk { struct WalkOptions {} }`."

    final class Visitor: SyntaxVisitor {
        let source: Source.File
        let severity: Diagnostic.Severity
        let converter: SourceLocationConverter
        var matches: [Diagnostic.Record] = []
        // Stack of enclosing namespace names. The top is the immediate
        // parent at the current visit point.
        var enclosingStack: [Swift.String] = []

        init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
            self.source = source
            self.severity = severity
            self.converter = converter
            super.init(viewMode: .sourceAccurate)
        }

        // MARK: - Type declarations: push name, check, descend.

        override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
            checkPrefixIfNested(name: node.name)
            enclosingStack.append(node.name.text)
            return .visitChildren
        }
        override func visitPost(_: StructDeclSyntax) { _ = enclosingStack.popLast() }

        override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
            checkPrefixIfNested(name: node.name)
            enclosingStack.append(node.name.text)
            return .visitChildren
        }
        override func visitPost(_: ClassDeclSyntax) { _ = enclosingStack.popLast() }

        override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
            checkPrefixIfNested(name: node.name)
            enclosingStack.append(node.name.text)
            return .visitChildren
        }
        override func visitPost(_: EnumDeclSyntax) { _ = enclosingStack.popLast() }

        override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
            checkPrefixIfNested(name: node.name)
            enclosingStack.append(node.name.text)
            return .visitChildren
        }
        override func visitPost(_: ActorDeclSyntax) { _ = enclosingStack.popLast() }

        override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
            checkPrefixIfNested(name: node.name)
            enclosingStack.append(node.name.text)
            return .visitChildren
        }
        override func visitPost(_: ProtocolDeclSyntax) { _ = enclosingStack.popLast() }

        // MARK: - Extension: push extended-type's last component.

        override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
            let lastComponent = lastComponent(of: node.extendedType)
            enclosingStack.append(lastComponent)
            return .visitChildren
        }
        override func visitPost(_: ExtensionDeclSyntax) { _ = enclosingStack.popLast() }

        // MARK: - Helpers

        private func checkPrefixIfNested(name token: TokenSyntax) {
            guard let enclosing = enclosingStack.last else { return }
            let declName = token.text
            // Must be `<enclosing><Suffix>` where Suffix is non-empty AND
            // begins with an uppercase letter (so we don't flag e.g.
            // `Foobar` whose first 3 chars happen to match `Foo`).
            guard declName.count > enclosing.count else { return }
            guard declName.hasPrefix(enclosing) else { return }
            let suffixStart = declName.index(declName.startIndex, offsetBy: enclosing.count)
            let firstSuffixChar = declName[suffixStart]
            guard firstSuffixChar.isUppercase else { return }
            let location = converter.location(for: token.positionAfterSkippingLeadingTrivia)
            matches.append(Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: Lint.Rule.Naming.RedundantPrefix.id.underlying,
                message: Lint.Rule.Naming.RedundantPrefix.message
            ))
        }

        /// Returns the last component of a type expression — the most
        /// nested name. For `extension A.B.C` returns `C`; for
        /// `extension Foo<Bar>` returns `Foo`. Returns the empty string
        /// when the expression has no recognizable identifier (rare).
        private func lastComponent(of type: TypeSyntax) -> Swift.String {
            if let identifier = type.as(IdentifierTypeSyntax.self) {
                return identifier.name.text
            }
            if let member = type.as(MemberTypeSyntax.self) {
                return member.name.text
            }
            // Fallback for genericised forms: peel through GenericSpecialization.
            return ""
        }
    }
}
