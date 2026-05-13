// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-linter open source project
//
// Copyright (c) 2026 Coen ten Thije Boonkkamp and the swift-linter project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

public import Linter_Primitives
internal import SwiftSyntax

/// R5 — `__unchecked:` argument label appearing at a call site.
///
/// Distinguishes call-site uses (anti-pattern per [CONV-016] tier 5) from
/// declaration-site uses (legitimate extension-init machinery per [CONV-001]).
/// The distinction is structural: call-site arguments parse as
/// `LabeledExprSyntax` (a `LabeledExprSyntax.label` token whose text equals
/// `__unchecked`); declaration-site parameters parse as
/// `FunctionParameterSyntax` (a `FunctionParameterSyntax.firstName` token).
/// This rule visits only the former.
///
/// References:
/// - `swift-institute/Research/cardinal-ordinal-vector-enforcement-design.md`
///   §"R5. `__unchecked:` use at call sites" — the original DEFER rationale.
/// - `swift-institute/Research/swiftsyntax-based-custom-linter-investigation.md`
///   §"Q3 — Deferred AST-rule unblocking matrix" — R5 is unblocked by this tool.
extension Lint.Rule {
    public static let `unchecked call site` = Lint.Rule(
        id: "unchecked call site",
        default: .warning,
        findings: { source, severity in
            let visitor = UncheckedVisitor(
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
internal let uncheckedCallSiteMessage: Swift.String =
    "[unchecked call site] [CONV-016]: `__unchecked:` at a call site is a Tier-5 "
    + "last-resort bypass of the typed system. Prefer `.retag()` (Tier 1) or `.map()` "
    + "(Tier 2) before resorting to `__unchecked:`. If this site is the typed-system "
    + "bottom-out (extension-init internals, [CONV-001] permitted same-package use), "
    + "escalate to supervisor and apply "
    + "`// swift-linter:disable:next unchecked call site` with a "
    + "`// REASON: <citation>` continuation."

internal final class UncheckedVisitor: SyntaxVisitor {
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

    override func visit(_ node: LabeledExprSyntax) -> SyntaxVisitorContinueKind {
        guard let label = node.label, label.text == "__unchecked" else {
            return .visitChildren
        }
        let location = converter.location(for: label.positionAfterSkippingLeadingTrivia)
        matches.append(Diagnostic.Record(
            location: Source.Location(
                fileID: source.fileID,
                filePath: source.filePath,
                line: location.line,
                column: location.column
            ),
            severity: severity,
            identifier: "unchecked call site",
            message: uncheckedCallSiteMessage
        ))
        return .visitChildren
    }
}
