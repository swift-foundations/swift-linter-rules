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

/// Wave 4 (mechanization-program) — platform-specific packages MUST
/// extend the shared `Kernel` namespace rather than declaring compound
/// platform-prefix root types.
///
/// Citation: `[PLAT-ARCH-003]` (platform skill — namespace extension
/// pattern).
extension Lint.Rule {
    public static let `compound platform namespace root` = Lint.Rule(
        id: "compound platform namespace root",
        defaultSeverity: .warning,
        findings: { source, severity in
            let visitor = PlatformNamespaceRootVisitor(
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
internal let platformNamespaceRootMessage: Swift.String =
    "[compound platform namespace root] [PLAT-ARCH-003]: top-level "
    + "compound platform-prefix type (e.g., `LinuxKernel`, "
    + "`KqueueEventNotification`) fragments the kernel namespace. Extend "
    + "the shared `Kernel` namespace via `extension Kernel { ... }` so the "
    + "platform discriminator lives in the import, not the type name."

internal let platformNamespaceRootPlatformPrefixes: [Swift.String] = ["Linux", "Darwin", "Windows"]
internal let platformNamespaceRootKernelKeywords: [Swift.String] = [
    "Kernel", "Kqueue", "Epoll", "IOCP", "IoUring", "EventNotification",
]

internal func platformNamespaceRootIsCompoundPlatformName(_ name: Swift.String) -> Swift.Bool {
    for prefix in platformNamespaceRootPlatformPrefixes {
        guard name.hasPrefix(prefix) else { continue }
        let suffix = String(name.dropFirst(prefix.count))
        for keyword in platformNamespaceRootKernelKeywords {
            if suffix.hasPrefix(keyword) {
                return true
            }
        }
    }
    for keyword in platformNamespaceRootKernelKeywords where keyword != "Kernel" {
        if name.hasPrefix(keyword) && name.count > keyword.count {
            let suffix = String(name.dropFirst(keyword.count))
            if let first = suffix.first, first.isUppercase {
                return true
            }
        }
    }
    return false
}

internal final class PlatformNamespaceRootVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    var matches: [Diagnostic.Record] = []
    var depth: Swift.Int = 0

    init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
        self.source = source
        self.severity = severity
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        if depth == 0 {
            flagIfCompound(node.name)
        }
        depth += 1
        return .visitChildren
    }
    override func visitPost(_: EnumDeclSyntax) {
        depth -= 1
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        if depth == 0 {
            flagIfCompound(node.name)
        }
        depth += 1
        return .visitChildren
    }
    override func visitPost(_: StructDeclSyntax) {
        depth -= 1
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        if depth == 0 {
            flagIfCompound(node.name)
        }
        depth += 1
        return .visitChildren
    }
    override func visitPost(_: ClassDeclSyntax) {
        depth -= 1
    }

    override func visit(_: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        depth += 1
        return .visitChildren
    }
    override func visitPost(_: ExtensionDeclSyntax) {
        depth -= 1
    }

    private func flagIfCompound(_ name: TokenSyntax) {
        guard platformNamespaceRootIsCompoundPlatformName(name.text) else {
            return
        }
        let location = converter.location(for: name.positionAfterSkippingLeadingTrivia)
        matches.append(Diagnostic.Record(
            location: Source.Location(
                fileID: source.fileID,
                filePath: source.filePath,
                line: location.line,
                column: location.column
            ),
            severity: severity,
            identifier: "compound platform namespace root",
            message: platformNamespaceRootMessage
        ))
    }
}
