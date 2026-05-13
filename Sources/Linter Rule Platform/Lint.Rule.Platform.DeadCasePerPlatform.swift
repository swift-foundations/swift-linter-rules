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
extension Lint.Rule {
    public static let `dead case per platform` = Lint.Rule(
        id: "dead case per platform",
        default: .warning,
        findings: { source, severity in
            let visitor = PlatformDeadCasePerPlatformVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.walk(source.tree)
            return visitor.matches
        }
    )
}

@usableFromInline
internal let platformDeadCasePerPlatformMessage: Swift.String =
    "[dead case per platform] [PATTERN-056]: public enum cases "
    + "enumerate platforms (POSIX / Windows or UTF8 / UTF16). Consumer "
    + "`switch` statements get N-1 dead branches per platform. Replace "
    + "with the ecosystem's existing platform-conditional typealias "
    + "(`Path.Char`, `String.Char`) for storage; add a local `Encoding` "
    + "typealias for decoder calls."

internal let platformDeadCasePerPlatformPlatformPairs: [Swift.Set<Swift.String>] = [
    ["posix", "windows"],
    ["utf8", "utf16"],
    ["linux", "darwin"],
    ["linux", "darwin", "windows"],
    ["linux", "darwin", "windows", "freebsd"],
]

internal func platformDeadCasePerPlatformMatchesPlatformPair(_ cases: [Swift.String]) -> Swift.Bool {
    let lower = Swift.Set(cases.map { $0.lowercased() })
    for pair in platformDeadCasePerPlatformPlatformPairs {
        if lower == pair {
            return true
        }
    }
    return false
}

internal final class PlatformDeadCasePerPlatformVisitor: SyntaxVisitor {
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
        guard platformDeadCasePerPlatformMatchesPlatformPair(caseNames) else {
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
            identifier: "dead case per platform",
            message: platformDeadCasePerPlatformMessage
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
