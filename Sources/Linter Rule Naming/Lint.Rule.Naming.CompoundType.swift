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

/// Wave 1 (mechanization-program) — compound type names at declaration site.
///
/// Citation: `[API-NAME-001]` (code-surface skill — Nest.Name pattern).
extension Lint.Rule {
    public static let `compound type name` = Lint.Rule(
        id: "compound type name",
        defaultSeverity: .warning,
        findings: { source, severity in
            let visitor = NamingCompoundTypeVisitor(
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
internal let namingCompoundTypeMessage: Swift.String =
    "[compound type name] [API-NAME-001]: types MUST use the `Nest.Name` "
    + "pattern. Compound type names like `FileDirectoryWalk` or "
    + "`DirectoryWalk` are forbidden — use the nested form "
    + "(`File.Directory.Walk`). Acronyms (`URL`, `UUID`, `IO`) are "
    + "permitted as single-word names; spec-namespace forms with "
    + "underscores (`RFC_4122`, `ISO_9945`) are exempt per "
    + "`[API-NAME-003]`. `package`-scope declarations and macro decls "
    + "are exempt."

internal final class NamingCompoundTypeVisitor: SyntaxVisitor {
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

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        check(name: node.name, modifiers: node.modifiers)
        return .visitChildren
    }
    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        check(name: node.name, modifiers: node.modifiers)
        return .visitChildren
    }
    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        check(name: node.name, modifiers: node.modifiers)
        return .visitChildren
    }
    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        check(name: node.name, modifiers: node.modifiers)
        return .visitChildren
    }
    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        check(name: node.name, modifiers: node.modifiers)
        return .visitChildren
    }

    // Macros are exempt per [API-NAME-001] — descend without checking.
    override func visit(_: MacroDeclSyntax) -> SyntaxVisitorContinueKind {
        .visitChildren
    }

    private func check(name token: TokenSyntax, modifiers: DeclModifierListSyntax) {
        guard !hasPackageModifier(modifiers) else { return }
        let text = token.text
        guard isCompoundTypeIdentifier(text) else { return }
        let location = converter.location(for: token.positionAfterSkippingLeadingTrivia)
        matches.append(Diagnostic.Record(
            location: Source.Location(
                fileID: source.fileID,
                filePath: source.filePath,
                line: location.line,
                column: location.column
            ),
            severity: severity,
            identifier: "compound type name",
            message: namingCompoundTypeMessage
        ))
    }

    private func hasPackageModifier(_ modifiers: DeclModifierListSyntax) -> Bool {
        for modifier in modifiers {
            if modifier.name.tokenKind == .keyword(.package) {
                return true
            }
        }
        return false
    }

    private func isCompoundTypeIdentifier(_ name: Swift.String) -> Bool {
        // Spec-namespace forms (`RFC_4122`, `ISO_9945`) — exempt.
        if name.contains("_") { return false }
        // Empty / single-char names — degenerate, not compound.
        guard name.count >= 2 else { return false }
        // Must start with uppercase to be a type identifier (sanity).
        let chars = Array(name)
        guard chars[0].isUppercase else { return false }
        // Word-boundary count.
        var words = 1
        var i = 1
        while i < chars.count {
            let prev = chars[i - 1]
            let curr = chars[i]
            let next: Swift.Character? = i + 1 < chars.count ? chars[i + 1] : nil
            if curr.isUppercase {
                // lowercase → uppercase: word boundary (FooBar)
                if prev.isLowercase {
                    words += 1
                } else if prev.isUppercase, let next, next.isLowercase {
                    // uppercase → uppercase → lowercase: acronym → word
                    // boundary (IOError ⇒ IO + Error at the E).
                    words += 1
                }
            }
            if words >= 2 { return true }
            i += 1
        }
        return false
    }
}
