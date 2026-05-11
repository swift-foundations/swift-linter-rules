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

/// Wave 3 (mechanization-program) — Foundation-free string scanning at
/// L1 / L2 MUST default to the UTF-8 byte view, not `unicodeScalars`.
///
/// Citation: `[IMPL-089]` (implementation skill — Foundation-free
/// string scanning defaults to UTF-8 byte view).
///
/// At the primitives / standards layers, byte-literal matching is the
/// right abstraction for the vast majority of scans (newline discovery,
/// substring search, percent decoding, path component splitting).
/// `Character` iteration introduces O(n²) re-indexing via grapheme
/// boundary analysis; `.unicodeScalars` adds a code-point layer that
/// still requires Unicode tables for normalisation and is heavier
/// than byte comparison for byte-literal scans. The institute default
/// is `content.utf8`; grapheme semantics are reserved for operations
/// that explicitly require them.
///
/// AST shape: walk `MemberAccessExprSyntax` whose member name is
/// `unicodeScalars`. Flag the member-name position. The rule cannot
/// confirm the base is a `String` without type info; bare
/// `.unicodeScalars` calls outside string scanning are unusual, so
/// the false-positive rate is acceptable — affected code paths can
/// document the exception.
///
/// Worked examples (flagged):
///   - `content.unicodeScalars.firstIndex(of: "\n")` — should be
///     `content.utf8.firstIndex(of: 0x0A)`.
///   - `for scalar in content.unicodeScalars { … }` — should be
///     `for byte in content.utf8 { … }`.
///
/// Worked examples (NOT flagged):
///   - `content.utf8.firstIndex(of: 0x0A)` — correct byte-view scan.
///   - `content.first` / `content.last` — direct Character access; out
///     of mechanical scope (the [IMPL-089] violation pattern is the
///     scanning loop, not single-character probes).
///   - String literals — out of scope; no `.unicodeScalars`.
extension Lint.Rule.Idiom {
    public struct StringUTF8Scanning: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "string_utf8_scanning"
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

extension Lint.Rule.Idiom.StringUTF8Scanning {
    @usableFromInline
    static let message: Swift.String =
        "[string_utf8_scanning] [IMPL-089]: `.unicodeScalars` access is "
        + "the wrong code-unit view for Foundation-free string scanning. "
        + "Use `.utf8` — byte-literal matching is O(n), no Unicode table "
        + "dependency, and the correct semantics for newline discovery, "
        + "substring search, percent decoding, path component splitting. "
        + "Reserve grapheme / scalar semantics for operations that "
        + "explicitly need them, and document the semantic choice at the "
        + "call site."

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

        override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
            guard node.declName.baseName.text == "unicodeScalars" else {
                return .visitChildren
            }
            let location = converter.location(
                for: node.declName.baseName.positionAfterSkippingLeadingTrivia
            )
            matches.append(Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: Lint.Rule.Idiom.StringUTF8Scanning.id.underlying,
                message: Lint.Rule.Idiom.StringUTF8Scanning.message
            ))
            return .visitChildren
        }
    }
}
