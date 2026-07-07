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

/// A `swift-linter:` suppression directive the engine's scanner will not
/// honor — silently inert, so the finding the author meant to suppress
/// still fires (or the author wrongly believes it is suppressed).
/// Citation: `[LINT-SUPPRESS-001]`.
///
/// The engine (`Lint.Suppression.scan`) recognizes EXACTLY two directive
/// forms, each requiring a non-empty rule id:
///   - `// swift-linter:disable:next <rule-id>`
///   - `// swift-linter:disable:line <rule-id>`
/// Any `//` line-comment whose content begins `swift-linter:` but does not
/// match one of those two is malformed: a block form
/// (`swift-linter:disable <id>` — no block form exists), an `enable` form
/// (none exists — `:next`/`:line` are self-scoped), a wrong sub-token
/// (`:this`, `:previous`), an empty rule id, or a missing space after `//`.
///
/// SCOPE: only the engine's OWN `swift-linter:` namespace. `swiftlint:`
/// directives are intentionally NOT flagged — whether a `swiftlint:disable`
/// names a rule known to the active config is config-dependent and is
/// SwiftLint's own concern (`superfluous_disable_command` /
/// `blanket_disable_command`), unreachable from a single parsed file.
/// Rule-id EXISTENCE (a well-formed directive naming an unknown rule) is
/// likewise out of scope: it needs the run's rule registry, not the file.
extension Lint.Rule {
    /// Flags a `swift-linter:` suppression comment that does not match the engine's grammar.
    public static let `malformed suppression directive` = Lint.Rule(
        id: "malformed suppression directive",
        default: .warning,
        findings: { source, severity in
            malformedSuppressionDirectiveFindings(
                tree: source.tree,
                file: source.file,
                converter: source.converter,
                severity: severity
            )
        }
    )
}

@usableFromInline
internal let malformedSuppressionDirectiveMessage: Swift.String =
    "[malformed suppression directive] [LINT-SUPPRESS-001]: this `swift-linter:` "
    + "suppression directive does not match the engine grammar and is silently "
    + "ignored — the finding it targets is NOT suppressed. Use "
    + "`// swift-linter:disable:next <rule-id>` or "
    + "`// swift-linter:disable:line <rule-id>` (no block form and no `enable` "
    + "form exist)."

// The two forms the engine honors, mirroring `Lint.Suppression`'s prefixes.
private let malformedSuppressionDisableNextPrefix = "// swift-linter:disable:next "
private let malformedSuppressionDisableLinePrefix = "// swift-linter:disable:line "

/// Walks every token's leading and trailing trivia, mirroring the cursor
/// arithmetic of `Lint.Suppression.scan` so reported line/column
/// match exactly where the engine would (or would fail to) parse a
/// directive.
internal func malformedSuppressionDirectiveFindings(
    tree: SourceFileSyntax,
    file: Source.File,
    converter: SourceLocationConverter,
    severity: Diagnostic.Severity
) -> [Diagnostic.Record] {
    var matches: [Diagnostic.Record] = []
    for token in tree.tokens(viewMode: .sourceAccurate) {
        scanTriviaForMalformedDirectives(
            token.leadingTrivia,
            tokenStartPosition: token.position,
            converter: converter,
            file: file,
            severity: severity,
            into: &matches
        )
        scanTriviaForMalformedDirectives(
            token.trailingTrivia,
            tokenStartPosition: token.endPositionBeforeTrailingTrivia,
            converter: converter,
            file: file,
            severity: severity,
            into: &matches
        )
    }
    return matches
}

private func scanTriviaForMalformedDirectives(
    _ trivia: Trivia,
    tokenStartPosition: AbsolutePosition,
    converter: SourceLocationConverter,
    file: Source.File,
    severity: Diagnostic.Severity,
    into matches: inout [Diagnostic.Record]
) {
    var cursor = tokenStartPosition
    for piece in trivia {
        let pieceStart = cursor
        let pieceLength = piece.sourceLength
        defer { cursor = cursor.advanced(by: pieceLength.utf8Length) }

        guard case .lineComment(let text) = piece else { continue }
        guard directiveIsMalformed(text) else { continue }

        let location = converter.location(for: pieceStart)
        matches.append(
            Diagnostic.Record(
                location: Source.Location(
                    fileID: file.fileID,
                    filePath: file.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "malformed suppression directive",
                message: malformedSuppressionDirectiveMessage
            )
        )
    }
}

/// True when `text` (a `//` line-comment) is INTENDED as a `swift-linter:`
/// directive (its content, after `//` and leading spaces, begins
/// `swift-linter:`) but does NOT match one of the two engine-honored forms
/// with a non-empty rule id.
internal func directiveIsMalformed(_ text: Swift.String) -> Swift.Bool {
    guard text.hasPrefix("//") else { return false }
    var rest = text.dropFirst(2)
    while let first = rest.first, first == " " { rest = rest.dropFirst() }
    guard rest.hasPrefix("swift-linter:") else { return false }

    for prefix in [malformedSuppressionDisableNextPrefix, malformedSuppressionDisableLinePrefix]
    where text.hasPrefix(prefix) {
        let suffix = text.dropFirst(prefix.count)
        // A well-formed directive carries a non-empty (non-whitespace) rule id.
        if suffix.contains(where: { !$0.isWhitespace }) { return false }
    }
    return true
}
