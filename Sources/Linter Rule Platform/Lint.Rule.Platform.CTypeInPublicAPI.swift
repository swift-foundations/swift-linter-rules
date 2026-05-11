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

/// Wave 4 (mechanization-program) — platform C types must not appear
/// in public API surfaces.
///
/// Citation: `[PLAT-ARCH-005a]` (platform skill — no platform C types
/// in public API).
///
/// Public APIs in the platform stack MUST NOT expose C types in
/// parameters, return types, or generic constraints. The institute
/// wraps every platform C type in an ecosystem type at L1 so consumers
/// never need to import the platform C module. The rule's mechanical
/// detection covers the canonical leak patterns: known C-type names
/// (`kevent`, `epoll_event`, `OVERLAPPED`, `sockaddr`, `iovec`,
/// `io_uring_sqe`, `io_uring_cqe`, `timespec`, `pid_t`, `HANDLE`,
/// `DWORD`) appearing in public function / initializer signatures.
///
/// AST shape: `FunctionDeclSyntax` / `InitializerDeclSyntax` whose
/// modifier list contains `public` (or `open`), AND whose parameter
/// type or return-type tree contains an `IdentifierTypeSyntax` whose
/// name is in the flagged-C-type set. Non-public visibility is
/// exempt (internal/private boundaries may legitimately use raw C
/// types per the rule's exception). Generic-argument wrappers
/// (`UnsafePointer<kevent>`, `UnsafeMutableBufferPointer<sockaddr>`)
/// recursively descend so the leaf C-type identifier is still caught.
extension Lint.Rule.Platform {
    public struct CTypeInPublicAPI: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "c_type_in_public_api"
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

extension Lint.Rule.Platform.CTypeInPublicAPI {
    @usableFromInline
    static let message: Swift.String =
        "[c_type_in_public_api] [PLAT-ARCH-005a]: platform C type appears in "
        + "public API signature. Public APIs in the platform stack MUST wrap "
        + "every C type in an ecosystem type at L1 so consumers never need to "
        + "import the platform C module. The flagged identifier is one of the "
        + "canonical leak patterns (`kevent`, `epoll_event`, `OVERLAPPED`, "
        + "`sockaddr`, `HANDLE`, etc.)."

    static let flaggedCTypes: Swift.Set<Swift.String> = [
        "kevent", "epoll_event", "OVERLAPPED", "sockaddr", "iovec",
        "io_uring_sqe", "io_uring_cqe", "timespec", "pid_t",
        "HANDLE", "DWORD", "WCHAR", "BOOL", "LPVOID", "WSABUF",
        "msghdr", "cmsghdr", "ifreq", "sockaddr_in", "sockaddr_in6",
        "sockaddr_un", "stat", "statfs", "dirent", "passwd",
    ]

    static func isPublicAPI(_ modifiers: DeclModifierListSyntax) -> Swift.Bool {
        for modifier in modifiers {
            switch modifier.name.tokenKind {
            case .keyword(.public), .keyword(.open):
                return true
            default:
                continue
            }
        }
        return false
    }

    static func containsCType(_ type: TypeSyntax) -> Swift.Bool {
        if let identifier = type.as(IdentifierTypeSyntax.self) {
            if flaggedCTypes.contains(identifier.name.text) {
                return true
            }
            if let arguments = identifier.genericArgumentClause {
                for argument in arguments.arguments {
                    if case .type(let argType) = argument.argument,
                       containsCType(argType) {
                        return true
                    }
                }
            }
            return false
        }
        if let optional = type.as(OptionalTypeSyntax.self) {
            return containsCType(optional.wrappedType)
        }
        if let array = type.as(ArrayTypeSyntax.self) {
            return containsCType(array.element)
        }
        if let attributed = type.as(AttributedTypeSyntax.self) {
            return containsCType(attributed.baseType)
        }
        if let member = type.as(MemberTypeSyntax.self) {
            if flaggedCTypes.contains(member.name.text) {
                return true
            }
            return false
        }
        return false
    }

    final class Visitor: SyntaxVisitor {
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

        override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
            checkSignature(
                modifiers: node.modifiers,
                signature: node.signature,
                emitAt: node.funcKeyword.positionAfterSkippingLeadingTrivia
            )
            return .visitChildren
        }

        override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
            checkSignature(
                modifiers: node.modifiers,
                signature: node.signature,
                emitAt: node.initKeyword.positionAfterSkippingLeadingTrivia
            )
            return .visitChildren
        }

        private func checkSignature(
            modifiers: DeclModifierListSyntax,
            signature: FunctionSignatureSyntax,
            emitAt position: AbsolutePosition
        ) {
            guard Lint.Rule.Platform.CTypeInPublicAPI.isPublicAPI(modifiers) else {
                return
            }
            var hit = false
            for parameter in signature.parameterClause.parameters {
                if Lint.Rule.Platform.CTypeInPublicAPI.containsCType(parameter.type) {
                    hit = true
                    break
                }
            }
            if !hit, let returnType = signature.returnClause?.type,
               Lint.Rule.Platform.CTypeInPublicAPI.containsCType(returnType) {
                hit = true
            }
            guard hit else { return }
            let location = converter.location(for: position)
            matches.append(Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: Lint.Rule.Platform.CTypeInPublicAPI.id.underlying,
                message: Lint.Rule.Platform.CTypeInPublicAPI.message
            ))
        }
    }
}
