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

/// Redundant-prefix declaration names: nested decls whose name starts
/// with the enclosing namespace. Citation: `[API-NAME-013]`.
extension Lint.Rule {
    public static let `redundant prefix` = Lint.Rule(
        id: "redundant_prefix",
        defaultSeverity: .warning,
        findings: { source, severity in
            let visitor = NamingRedundantPrefixVisitor(
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
internal let namingRedundantPrefixMessage: Swift.String =
    "[redundant_prefix] [API-NAME-013]: nested declaration name has a "
    + "redundant prefix that matches the enclosing namespace. Drop the "
    + "prefix — the containing type already supplies the context."

internal final class NamingRedundantPrefixVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    var matches: [Diagnostic.Record] = []
    var enclosingStack: [Swift.String] = []

    init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
        self.source = source
        self.severity = severity
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

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

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        let last = lastComponent(of: node.extendedType)
        enclosingStack.append(last)
        return .visitChildren
    }
    override func visitPost(_: ExtensionDeclSyntax) { _ = enclosingStack.popLast() }

    private func checkPrefixIfNested(name token: TokenSyntax) {
        guard let enclosing = enclosingStack.last else { return }
        let declName = token.text
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
            identifier: "redundant_prefix",
            message: namingRedundantPrefixMessage
        ))
    }

    private func lastComponent(of type: TypeSyntax) -> Swift.String {
        if let identifier = type.as(IdentifierTypeSyntax.self) { return identifier.name.text }
        if let member = type.as(MemberTypeSyntax.self) { return member.name.text }
        return ""
    }
}
