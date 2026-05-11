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
///
/// Compound platform-prefix top-level types (`public enum LinuxKernel`,
/// `public enum DarwinKernel`, `public enum WindowsKernel`,
/// `public enum KqueueEventNotification`) fragment the kernel namespace
/// — consumers must remember which platform-prefixed root holds which
/// API. The institute pattern: extend the shared `Kernel` namespace
/// via `extension Kernel { ... }` so the prefix lives in the import,
/// not in the type name.
///
/// AST shape: top-level (file-scope) `EnumDeclSyntax` / `StructDeclSyntax`
/// / `ClassDeclSyntax` whose name matches `<Platform><Kernel-like-noun>`
/// (e.g., `LinuxKernel`, `DarwinKernel`, `WindowsKernel`) OR matches the
/// `Kqueue*` / `Epoll*` / `IOCP*` compound prefixes that the rule body's
/// "Incorrect" example calls out. The check is conservative; the
/// declaration's package-scope (platform-specific vs. cross-platform)
/// is not mechanically verifiable from a single file, so the rule fires
/// on any compound-platform-noun match.
extension Lint.Rule.Platform {
    public struct NamespaceRoot: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "namespace_root_compound_platform"
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

extension Lint.Rule.Platform.NamespaceRoot {
    @usableFromInline
    static let message: Swift.String =
        "[namespace_root_compound_platform] [PLAT-ARCH-003]: top-level "
        + "compound platform-prefix type (e.g., `LinuxKernel`, "
        + "`KqueueEventNotification`) fragments the kernel namespace. Extend "
        + "the shared `Kernel` namespace via `extension Kernel { ... }` so the "
        + "platform discriminator lives in the import, not the type name."

    static let platformPrefixes: [Swift.String] = ["Linux", "Darwin", "Windows"]
    static let kernelKeywords: [Swift.String] = [
        "Kernel", "Kqueue", "Epoll", "IOCP", "IoUring", "EventNotification",
    ]

    static func isCompoundPlatformName(_ name: Swift.String) -> Swift.Bool {
        for prefix in platformPrefixes {
            guard name.hasPrefix(prefix) else { continue }
            let suffix = String(name.dropFirst(prefix.count))
            for keyword in kernelKeywords {
                if suffix.hasPrefix(keyword) {
                    return true
                }
            }
        }
        // Also flag bare compound names that match kernel-like patterns
        // without an explicit platform prefix.
        for keyword in kernelKeywords where keyword != "Kernel" {
            if name.hasPrefix(keyword) && name.count > keyword.count {
                let suffix = String(name.dropFirst(keyword.count))
                if let first = suffix.first, first.isUppercase {
                    return true
                }
            }
        }
        return false
    }

    final class Visitor: SyntaxVisitor {
        let source: Source.File
        let severity: Diagnostic.Severity
        let converter: SourceLocationConverter
        var matches: [Diagnostic.Record] = []
        // Track nesting depth — only top-level declarations are in scope.
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

        // Extensions count as scope but not as compound-name candidates.
        override func visit(_: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
            depth += 1
            return .visitChildren
        }
        override func visitPost(_: ExtensionDeclSyntax) {
            depth -= 1
        }

        private func flagIfCompound(_ name: TokenSyntax) {
            guard Lint.Rule.Platform.NamespaceRoot
                .isCompoundPlatformName(name.text) else {
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
                identifier: Lint.Rule.Platform.NamespaceRoot.id.underlying,
                message: Lint.Rule.Platform.NamespaceRoot.message
            ))
        }
    }
}
