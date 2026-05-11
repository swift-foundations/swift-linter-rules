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
///
/// `System` is a cross-platform concept (processor count, memory,
/// NUMA topology). Platform-specific discovery (sysctl, /proc/meminfo,
/// WinSDK) is *mechanism*, not a new domain. Nesting `System` under
/// the platform namespace creates an unnecessary indirection and
/// would require `Core` to be published per `[PLAT-ARCH-027]`. The
/// canonical shape extends the cross-platform `System.*` types
/// directly from each platform's System target.
///
/// AST shape: two detection forms.
///   1. `extension Darwin.System { … }` — extendedType is a member-type
///      chain `<Platform>.System` for one of Darwin / Linux / Windows.
///   2. `extension Darwin { enum System { … } }` or `enum Darwin { enum
///      System { … } }` — `System` declared as a nested type inside a
///      platform namespace.
///
/// Worked examples (flagged):
///   - `extension Darwin.System { public static func op() { … } }`
///   - `extension Linux { public enum System { } }`
///   - `enum Windows { enum System { } }`
///
/// Worked examples (NOT flagged):
///   - `extension System { public static func op() { … } }` — extends
///     `System` directly.
///   - `extension Darwin { public enum Kernel { } }` — non-System
///     subdomain; out of scope.
///   - `enum System { … }` at file scope — the cross-platform namespace.
extension Lint.Rule.Platform {
    public struct SystemSubdomain: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "platform_system_subdomain"
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

extension Lint.Rule.Platform.SystemSubdomain {
    @usableFromInline
    static let message: Swift.String =
        "[platform_system_subdomain] [PLAT-ARCH-026]: `System` must NOT be "
        + "a subdomain of `Darwin` / `Linux` / `Windows`. Platform System "
        + "targets extend the cross-platform `System` namespace directly "
        + "— platform-specific discovery (sysctl, /proc/meminfo, WinSDK) "
        + "is mechanism, not a new domain. Nesting forces Core to be "
        + "published per [PLAT-ARCH-027]; the variant `@_exported` re-"
        + "export carries the namespace without that publication step."

    static let platformNamespaces: Swift.Set<Swift.String> = [
        "Darwin",
        "Linux",
        "Windows",
    ]

    /// Returns true when `type` is `<Platform>.System` where Platform
    /// is one of Darwin / Linux / Windows. Position returned for emission.
    static func isPlatformSystemMemberType(
        _ type: TypeSyntax
    ) -> AbsolutePosition? {
        guard let member = type.as(MemberTypeSyntax.self) else { return nil }
        guard member.name.text == "System" else { return nil }
        guard let base = member.baseType.as(IdentifierTypeSyntax.self) else {
            return nil
        }
        guard platformNamespaces.contains(base.name.text) else { return nil }
        return member.name.positionAfterSkippingLeadingTrivia
    }

    final class Visitor: SyntaxVisitor {
        let source: Source.File
        let severity: Diagnostic.Severity
        let converter: SourceLocationConverter
        var matches: [Diagnostic.Record] = []
        /// Stack of enclosing namespace identifiers (enum/extension
        /// names). Used to detect a nested `enum System` inside one of
        /// the platform namespaces.
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
                identifier: Lint.Rule.Platform.SystemSubdomain.id.underlying,
                message: Lint.Rule.Platform.SystemSubdomain.message
            ))
        }

        /// Returns the identifier-text of the LAST component in an
        /// extension's extendedType — used as the stack entry.
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
            // Detection form (1): `extension Darwin.System { … }`.
            if let position = Lint.Rule.Platform.SystemSubdomain.isPlatformSystemMemberType(
                node.extendedType
            ) {
                emit(at: position)
            }
            // Push leaf for nested-type detection.
            nameStack.append(Visitor.extensionLeafName(node.extendedType) ?? "")
            return .visitChildren
        }
        override func visitPost(_: ExtensionDeclSyntax) { nameStack.removeLast() }

        override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
            // Detection form (2/3): nested `enum System` inside one of
            // the platform namespaces.
            if node.name.text == "System" {
                if let last = nameStack.last,
                   Lint.Rule.Platform.SystemSubdomain.platformNamespaces.contains(last)
                {
                    emit(at: node.name.positionAfterSkippingLeadingTrivia)
                }
            }
            nameStack.append(node.name.text)
            return .visitChildren
        }
        override func visitPost(_: EnumDeclSyntax) { nameStack.removeLast() }

        // Push struct/class/actor names too — these aren't expected as
        // platform namespaces, but track for correctness.
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
}
