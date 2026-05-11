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

/// Wave 3 (mechanization-program) — platform System targets MUST extend
/// the `System` namespace directly, NOT nest under
/// `{Platform}.System`.
///
/// Citation: `[PLAT-ARCH-026]` (platform skill — platform System
/// extends System directly).
extension Lint.Rule {
    public static let `system subdomain` = Lint.Rule(
        id: "platform_system_subdomain",
        defaultSeverity: .warning,
        findings: { source, severity in
            let visitor = PlatformSystemSubdomainVisitor(
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
internal let platformSystemSubdomainMessage: Swift.String =
    "[platform_system_subdomain] [PLAT-ARCH-026]: `System` must NOT be "
    + "a subdomain of `Darwin` / `Linux` / `Windows`. Platform System "
    + "targets extend the cross-platform `System` namespace directly "
    + "— platform-specific discovery (sysctl, /proc/meminfo, WinSDK) "
    + "is mechanism, not a new domain. Nesting forces Core to be "
    + "published per [PLAT-ARCH-027]; the variant `@_exported` re-"
    + "export carries the namespace without that publication step."

internal let platformSystemSubdomainPlatformNamespaces: Swift.Set<Swift.String> = [
    "Darwin",
    "Linux",
    "Windows",
]

internal func platformSystemSubdomainIsPlatformSystemMemberType(
    _ type: TypeSyntax
) -> AbsolutePosition? {
    guard let member = type.as(MemberTypeSyntax.self) else { return nil }
    guard member.name.text == "System" else { return nil }
    guard let base = member.baseType.as(IdentifierTypeSyntax.self) else {
        return nil
    }
    guard platformSystemSubdomainPlatformNamespaces.contains(base.name.text) else { return nil }
    return member.name.positionAfterSkippingLeadingTrivia
}

internal final class PlatformSystemSubdomainVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    var matches: [Diagnostic.Record] = []
    var nameStack: [Swift.String] = []

    init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
        self.source = source
        self.severity = severity
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    private func emit(at position: AbsolutePosition) {
        let location = converter.location(for: position)
        matches.append(Diagnostic.Record(
            location: Source.Location(
                fileID: source.fileID,
                filePath: source.filePath,
                line: location.line,
                column: location.column
            ),
            severity: severity,
            identifier: "platform_system_subdomain",
            message: platformSystemSubdomainMessage
        ))
    }

    private static func extensionLeafName(_ type: TypeSyntax) -> Swift.String? {
        if let identifier = type.as(IdentifierTypeSyntax.self) {
            return identifier.name.text
        }
        if let member = type.as(MemberTypeSyntax.self) {
            return member.name.text
        }
        return nil
    }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        if let position = platformSystemSubdomainIsPlatformSystemMemberType(
            node.extendedType
        ) {
            emit(at: position)
        }
        nameStack.append(PlatformSystemSubdomainVisitor.extensionLeafName(node.extendedType) ?? "")
        return .visitChildren
    }
    override func visitPost(_: ExtensionDeclSyntax) { nameStack.removeLast() }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        if node.name.text == "System" {
            if let last = nameStack.last,
               platformSystemSubdomainPlatformNamespaces.contains(last)
            {
                emit(at: node.name.positionAfterSkippingLeadingTrivia)
            }
        }
        nameStack.append(node.name.text)
        return .visitChildren
    }
    override func visitPost(_: EnumDeclSyntax) { nameStack.removeLast() }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        nameStack.append(node.name.text)
        return .visitChildren
    }
    override func visitPost(_: StructDeclSyntax) { nameStack.removeLast() }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        nameStack.append(node.name.text)
        return .visitChildren
    }
    override func visitPost(_: ClassDeclSyntax) { nameStack.removeLast() }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        nameStack.append(node.name.text)
        return .visitChildren
    }
    override func visitPost(_: ActorDeclSyntax) { nameStack.removeLast() }
}
