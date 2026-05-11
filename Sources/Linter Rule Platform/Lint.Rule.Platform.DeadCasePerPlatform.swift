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

/// Wave 4 (mechanization-program) — public enum whose cases enumerate
/// platforms (POSIX / Windows, or UTF8 / UTF16) is the dead-case anti-
/// pattern in disguise.
///
/// Citation: `[PATTERN-056]` (implementation skill, patterns.md).
///
/// A public enum with N unconditional cases where each case is
/// constructed unconditionally on different platforms is an anti-
/// pattern: consumer `switch` statements have N-1 dead branches per
/// platform. The institute fix: replace with the ecosystem's existing
/// platform-conditional typealias (`Path.Char`, `String.Char`) for
/// storage; add a local `Encoding` typealias (`UTF8` / `UTF16`) for
/// decoder calls.
///
/// AST shape: `EnumDeclSyntax` with `public` access AND whose case
/// names match a curated set of platform-aligned pairs:
///   - {posix, windows} / {POSIX, Windows}
///   - {utf8, utf16} / {UTF8, UTF16}
///   - {linux, darwin, windows}
/// The match is narrow and case-name-driven; enums whose cases name
/// genuine domain alternatives (e.g., `case http`, `case https`,
/// `case ftp`) are not flagged. Number of cases is 2-4 (the platform
/// count for our supported platforms).
extension Lint.Rule.Platform {
    public struct DeadCasePerPlatform: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "dead_case_per_platform_enum"
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

extension Lint.Rule.Platform.DeadCasePerPlatform {
    @usableFromInline
    static let message: Swift.String =
        "[dead_case_per_platform_enum] [PATTERN-056]: public enum cases "
        + "enumerate platforms (POSIX / Windows or UTF8 / UTF16). Consumer "
        + "`switch` statements get N-1 dead branches per platform. Replace "
        + "with the ecosystem's existing platform-conditional typealias "
        + "(`Path.Char`, `String.Char`) for storage; add a local `Encoding` "
        + "typealias for decoder calls."

    static let platformPairs: [Swift.Set<Swift.String>] = [
        ["posix", "windows"],
        ["utf8", "utf16"],
        ["linux", "darwin"],
        ["linux", "darwin", "windows"],
        ["linux", "darwin", "windows", "freebsd"],
    ]

    static func matchesPlatformPair(_ cases: [Swift.String]) -> Swift.Bool {
        let lower = Swift.Set(cases.map { $0.lowercased() })
        for pair in platformPairs {
            if lower == pair {
                return true
            }
        }
        return false
    }

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

        override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
            guard hasPublicAccess(node.modifiers) else { return .visitChildren }
            var caseNames: [Swift.String] = []
            for member in node.memberBlock.members {
                guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else {
                    continue
                }
                for element in caseDecl.elements {
                    caseNames.append(element.name.text)
                }
            }
            guard caseNames.count >= 2, caseNames.count <= 4 else {
                return .visitChildren
            }
            guard Lint.Rule.Platform.DeadCasePerPlatform
                .matchesPlatformPair(caseNames) else {
                return .visitChildren
            }
            let location = converter.location(
                for: node.enumKeyword.positionAfterSkippingLeadingTrivia
            )
            matches.append(Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: Lint.Rule.Platform.DeadCasePerPlatform.id.underlying,
                message: Lint.Rule.Platform.DeadCasePerPlatform.message
            ))
            return .visitChildren
        }

        private func hasPublicAccess(_ modifiers: DeclModifierListSyntax) -> Swift.Bool {
            for modifier in modifiers {
                switch modifier.name.tokenKind {
                case .keyword(.public), .keyword(.open):
                    return true
                default:
                    continue
                }
            }
            return false
        }
    }
}
