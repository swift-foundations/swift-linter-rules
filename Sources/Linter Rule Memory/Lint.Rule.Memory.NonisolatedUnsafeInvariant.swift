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

/// Wave 3 Thread 7 (2026-05-11) — `nonisolated(unsafe)` declarations
/// MUST carry an adjacent `// SAFETY: ...` or `// WHY: ...` invariant
/// comment that cites the encapsulation guarantee in prose.
///
/// Citation: `[MEM-SAFE-025a]` (memory-safety skill, safety-isolation.md).
///
/// Replaces `Lint.Rule.Memory.NonisolatedUnsafeSafe` (the original
/// `[MEM-SAFE-025]` rule, SUPERSEDED 2026-05-11 by the
/// invariant-comment + `@safe`-forbidden split per
/// `swift-institute/Research/mem-safe-025-reconciliation.md`).
///
/// The comment MUST be immediately adjacent to the declaration: a
/// blank line between the comment and the `nonisolated(unsafe)` token
/// breaks adjacency and the rule fires. Multi-line `// SAFETY:` /
/// `// WHY:` blocks are accepted as long as the LAST comment line
/// before the declaration is one of those forms.
extension Lint.Rule {
    public static let `nonisolated unsafe without invariant` = Lint.Rule(
        id: "nonisolated unsafe without invariant",
        default: .warning,
        findings: { source, severity in
            let visitor = MemoryNonisolatedUnsafeInvariantVisitor(
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
internal let memoryNonisolatedUnsafeInvariantMessage: Swift.String =
    "[nonisolated unsafe without invariant] [MEM-SAFE-025a]: `nonisolated(unsafe)` "
    + "declarations MUST carry an adjacent `// SAFETY:` or `// WHY:` comment "
    + "citing the encapsulation invariant (allocated once / never mutated post-init / "
    + "sync mechanism / ownership discipline). The comment MUST immediately precede "
    + "the declaration with no intervening blank line. Multi-line `// SAFETY:` or "
    + "`// WHY:` blocks are accepted."

internal final class MemoryNonisolatedUnsafeInvariantVisitor: SyntaxVisitor {
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

    private func hasNonisolatedUnsafe(_ modifiers: DeclModifierListSyntax) -> Bool {
        for modifier in modifiers {
            if modifier.name.tokenKind == .keyword(.nonisolated) {
                if let detail = modifier.detail {
                    // detail is `(unsafe)` — match by trimmed text.
                    if detail.detail.text == "unsafe" {
                        return true
                    }
                }
            }
        }
        return false
    }

    /// Returns `true` if the variable declaration's leading trivia
    /// contains an adjacent `// SAFETY:` or `// WHY:` line.
    ///
    /// "Adjacent" means: starting from the end of the leading trivia,
    /// walking backwards, the first `lineComment` we encounter MUST be
    /// a `// SAFETY:` or `// WHY:` form AND there MUST NOT be a blank
    /// line (two or more consecutive newlines) between that comment
    /// and the declaration token.
    private func hasAdjacentInvariantComment(_ trivia: Trivia) -> Bool {
        let pieces = Swift.Array(trivia)
        // Walk back from the end. State machine:
        //   - newlinesSinceLastComment counts consecutive newlines AFTER
        //     the last comment (i.e., between the comment and the token).
        //   - We stop at the first lineComment we encounter and decide.
        //   - If we see >=2 newlines before we reach any comment, no adjacency.
        var newlinesSinceLastComment = 0
        for piece in pieces.reversed() {
            switch piece {
            case .newlines(let count):
                newlinesSinceLastComment += count
                // 2+ consecutive newlines means a blank line between
                // any earlier comment and the declaration — adjacency
                // broken.
                if newlinesSinceLastComment >= 2 { return false }
            case .lineComment(let text):
                // First comment we hit walking back. Decide based on
                // its content and the newline count to the token.
                //
                // newlinesSinceLastComment must be at most 1 (the
                // single newline that separates `// foo\n` from the
                // next declaration line). If we already saw 2+ above
                // we'd have returned false; we also need to NOT have
                // seen zero newlines (which would be a trailing
                // comment on the same line as some other token earlier
                // in the trivia — not the adjacency we want, but
                // SwiftSyntax's leading trivia model puts a newline
                // before line comments parsed off the previous line).
                let trimmed = text.trimmingPrefix("//")
                let body = trimmed.drop(while: { $0 == " " || $0 == "\t" })
                if body.hasPrefix("SAFETY:") || body.hasPrefix("WHY:") {
                    return true
                }
                // First comment we found is not SAFETY/WHY — keep
                // walking back; an earlier multi-line block might
                // have started with SAFETY/WHY, but the institute's
                // convention is that EVERY line of the block carries
                // the prefix (`// SAFETY: ...\n// SAFETY: ...`). If
                // the comment line immediately above the decl isn't
                // SAFETY/WHY, the invariant isn't being asserted at
                // the adjacent line.
                return false
            case .blockComment, .docLineComment, .docBlockComment:
                // Block / doc comments do not satisfy the convention
                // (the institute uses `// SAFETY:` / `// WHY:` for
                // the encapsulation invariant; doc comments are for
                // API-surface documentation). Treat as adjacency
                // boundary but not as the invariant.
                return false
            case .spaces, .tabs:
                continue
            case .carriageReturns, .carriageReturnLineFeeds:
                newlinesSinceLastComment += piece.sourceLength.utf8Length > 0 ? 1 : 0
                if newlinesSinceLastComment >= 2 { return false }
            default:
                continue
            }
        }
        return false
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        guard hasNonisolatedUnsafe(node.modifiers) else {
            return .visitChildren
        }
        // The relevant leading trivia is the one on the first token
        // of the declaration. For a variable decl that's the first
        // attribute or modifier — `node.leadingTrivia` resolves to
        // that.
        let trivia = node.leadingTrivia
        if hasAdjacentInvariantComment(trivia) {
            return .visitChildren
        }
        let location = converter.location(for: node.bindingSpecifier.positionAfterSkippingLeadingTrivia)
        matches.append(Diagnostic.Record(
            location: Source.Location(
                fileID: source.fileID,
                filePath: source.filePath,
                line: location.line,
                column: location.column
            ),
            severity: severity,
            identifier: "nonisolated unsafe without invariant",
            message: memoryNonisolatedUnsafeInvariantMessage
        ))
        return .visitChildren
    }
}
