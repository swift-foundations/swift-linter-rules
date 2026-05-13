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

/// `throws(Self.Error)` resolves only inside a protocol declaration with an
/// `associatedtype Error` requirement. Everywhere else — struct, class, enum,
/// or extension on a concrete type — the institute convention writes the
/// fully-nested error type. Citation: `[API-ERR-002]`.
extension Lint.Rule {
    public static let `typed throws cannot use self error` = Lint.Rule(
        id: "typed throws cannot use self error",
        default: .warning,
        findings: { source, severity in
            let visitor = ThrowsSelfErrorInTypedThrowsVisitor(
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
internal let throwsSelfErrorInTypedThrowsMessage: Swift.String =
    "[typed throws cannot use self error] [API-ERR-002]: `throws(Self.Error)` "
    + "resolves only inside a protocol declaration with `associatedtype Error`. "
    + "In a struct, class, enum, or extension on a concrete type, write the "
    + "fully-nested error type — `throws(Random.Error)`, "
    + "`throws(Storage.Pool.Error)`. `Self.Error` in `throws(...)` is forbidden "
    + "by the institute convention."

internal final class ThrowsSelfErrorInTypedThrowsVisitor: SyntaxVisitor {
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

    override func visit(_ node: ThrowsClauseSyntax) -> SyntaxVisitorContinueKind {
        guard let typed = node.type else { return .visitChildren }
        guard isSelfError(typed) else { return .visitChildren }
        guard shouldFlag(Syntax(node)) else { return .visitChildren }
        let location = converter.location(for: typed.positionAfterSkippingLeadingTrivia)
        matches.append(Diagnostic.Record(
            location: Source.Location(
                fileID: source.fileID,
                filePath: source.filePath,
                line: location.line,
                column: location.column
            ),
            severity: severity,
            identifier: "typed throws cannot use self error",
            message: throwsSelfErrorInTypedThrowsMessage
        ))
        return .visitChildren
    }

    private func isSelfError(_ type: TypeSyntax) -> Swift.Bool {
        guard let member = type.as(MemberTypeSyntax.self),
              member.name.text == "Error",
              let base = member.baseType.as(IdentifierTypeSyntax.self),
              base.name.text == "Self"
        else { return false }
        return true
    }

    /// Returns true iff `throws(Self.Error)` at this node is invalid per
    /// institute convention. Concrete-type contexts (`struct`/`class`/`enum`/
    /// `actor` bodies, and extensions on concrete types) resolve `Self.Error`
    /// to the nested error member and are exempt. Protocol declarations are
    /// flagged unless they declare `associatedtype Error`. Extensions are not
    /// flagged here — distinguishing a protocol extension from a concrete-type
    /// extension requires symbol resolution the linter does not have.
    private func shouldFlag(_ node: Syntax) -> Swift.Bool {
        var current: Syntax? = node.parent
        while let parent = current {
            if let proto = parent.as(ProtocolDeclSyntax.self) {
                return !declaresAssociatedError(proto)
            }
            if parent.is(StructDeclSyntax.self)
                || parent.is(ClassDeclSyntax.self)
                || parent.is(EnumDeclSyntax.self)
                || parent.is(ActorDeclSyntax.self)
                || parent.is(ExtensionDeclSyntax.self)
            {
                return false
            }
            current = parent.parent
        }
        return false
    }

    private func declaresAssociatedError(_ proto: ProtocolDeclSyntax) -> Swift.Bool {
        for member in proto.memberBlock.members {
            if let associated = member.decl.as(AssociatedTypeDeclSyntax.self),
               associated.name.text == "Error"
            { return true }
        }
        return false
    }
}
