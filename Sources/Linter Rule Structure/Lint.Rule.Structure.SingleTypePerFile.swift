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

/// Wave 2b finalization (2026-05-10) — one type declaration per file.
///
/// Citation: `[API-IMPL-005]` (code-surface skill).
///
/// Each `.swift` source file MUST contain exactly one type *declaration*
/// (`struct`, `class`, `enum`, `actor`, `protocol`). Multiple `extension`
/// declarations of the same enclosing type are PERMITTED — `extension` is
/// not a type declaration; it adds members or conformances to one.
///
/// Per Wave 2b finalization Decision 2, this rule scopes to `Sources/`
/// only. `Tests/*`, `Experiments/*`, and `Examples/*` are out of scope —
/// test fixture files routinely declare multiple top-level types per
/// `[TEST-005]` and the deferred Phase 1.5 sub-config-fanout discussion
/// in `swift-institute/.github/.swiftlint.yml`.
///
/// AST shape: count file-scope `StructDeclSyntax`, `ClassDeclSyntax`,
/// `EnumDeclSyntax`, `ActorDeclSyntax`, `ProtocolDeclSyntax`. > 1 → flag
/// the second-and-subsequent type declarations.
extension Lint.Rule.Structure {
    public struct SingleTypePerFile: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "single_type_per_file"
        public static let defaultSeverity: Diagnostic.Severity = .warning

        public let severity: Diagnostic.Severity

        @inlinable
        public init(severity: Diagnostic.Severity = .warning) {
            self.severity = severity
        }

        public func findings(in source: Lint.Source.Parsed) -> [Diagnostic.Record] {
            // Scope-exclusion per Decision 2: skip files whose path has a
            // segment named `Tests`, `Experiments`, or `Examples`. Both
            // absolute (`/.../Tests/...`) and relative (`Tests/...`) forms
            // are recognized.
            let path = source.file.filePath.underlying
            for excluded in ["Tests", "Experiments", "Examples"] {
                if path == excluded
                    || path.hasPrefix("\(excluded)/")
                    || path.contains("/\(excluded)/")
                {
                    return []
                }
            }
            let visitor = Visitor(source: source.file, severity: severity, converter: source.converter)
            visitor.walk(source.tree)
            return visitor.matches
        }
    }
}

extension Lint.Rule.Structure.SingleTypePerFile {
    @usableFromInline
    static let message: Swift.String =
        "[single_type_per_file] [API-IMPL-005]: each `.swift` source file MUST contain "
        + "exactly one type declaration (`struct`, `class`, `enum`, `actor`, `protocol`). "
        + "Multiple `extension` declarations of the enclosing type are permitted. "
        + "Move additional types to their own files; the file naming convention "
        + "[API-IMPL-006] requires the file name to match the type's nested path."

    final class Visitor: SyntaxVisitor {
        let source: Source.File
        let severity: Diagnostic.Severity
        let converter: SourceLocationConverter
        var matches: [Diagnostic.Record] = []
        // Track depth of enclosing type bodies so nested types are NOT
        // counted as additional file-scope declarations.
        var currentDepth: Int = 0
        // Counter of file-scope type decls seen so far. The first is
        // permitted; the second+ is flagged as a violation.
        var topLevelCount: Int = 0

        init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
            self.source = source
            self.severity = severity
            self.converter = converter
            super.init(viewMode: .sourceAccurate)
        }

        private func handleTypeDecl(at position: AbsolutePosition) {
            guard currentDepth == 0 else { return }
            topLevelCount += 1
            // First top-level type is permitted; flag subsequent ones.
            guard topLevelCount > 1 else { return }
            let location = converter.location(for: position)
            matches.append(Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: Lint.Rule.Structure.SingleTypePerFile.id.underlying,
                message: Lint.Rule.Structure.SingleTypePerFile.message
            ))
        }

        override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
            handleTypeDecl(at: node.name.positionAfterSkippingLeadingTrivia)
            currentDepth += 1
            return .visitChildren
        }
        override func visitPost(_ node: StructDeclSyntax) { currentDepth -= 1 }

        override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
            handleTypeDecl(at: node.name.positionAfterSkippingLeadingTrivia)
            currentDepth += 1
            return .visitChildren
        }
        override func visitPost(_ node: ClassDeclSyntax) { currentDepth -= 1 }

        override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
            handleTypeDecl(at: node.name.positionAfterSkippingLeadingTrivia)
            currentDepth += 1
            return .visitChildren
        }
        override func visitPost(_ node: EnumDeclSyntax) { currentDepth -= 1 }

        override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
            handleTypeDecl(at: node.name.positionAfterSkippingLeadingTrivia)
            currentDepth += 1
            return .visitChildren
        }
        override func visitPost(_ node: ActorDeclSyntax) { currentDepth -= 1 }

        override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
            handleTypeDecl(at: node.name.positionAfterSkippingLeadingTrivia)
            currentDepth += 1
            return .visitChildren
        }
        override func visitPost(_ node: ProtocolDeclSyntax) { currentDepth -= 1 }

        // Extension declarations: descend without flagging — they don't
        // count as new type declarations under [API-IMPL-005]. An extension
        // contributes members/conformances to an existing type. Nested
        // types declared INSIDE an extension are nested-type declarations
        // and out of file-scope-count scope.
        override func visit(_: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
            currentDepth += 1
            return .visitChildren
        }
        override func visitPost(_: ExtensionDeclSyntax) { currentDepth -= 1 }
    }
}
