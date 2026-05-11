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

/// Wave 4 (mechanization-program) — `struct: @unchecked Sendable`
/// wrapping a class stored property is the anti-pattern.
///
/// Citation: `[IMPL-076]` (implementation skill, concurrency.md — no
/// @unchecked Sendable on struct-wrapping-class).
extension Lint.Rule {
    public static let `sendable struct with class member` = Lint.Rule(
        id: "sendable struct with class member",
        defaultSeverity: .warning,
        findings: { source, severity in
            let visitor = MemoryStructSendableClassMemberVisitor(
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
internal let memoryStructSendableClassMemberMessage: Swift.String =
    "[sendable struct with class member] [IMPL-076]: `struct: @unchecked Sendable` "
    + "wrapping a class-typed stored property is redundant — if the class is "
    + "itself `Sendable`, plain `Sendable` on the struct suffices. The "
    + "`@unchecked` annotation asserts safety the type system can already "
    + "discharge; drop it and conform to plain `Sendable`."

@usableFromInline
internal let memoryStructSendableClassMemberKnownClassNames: Swift.Set<Swift.String> = [
    "NSObject", "Thread", "DispatchQueue", "AnyObject",
]

internal func memoryStructSendableClassMemberLooksLikeClassType(_ name: Swift.String) -> Swift.Bool {
    if memoryStructSendableClassMemberKnownClassNames.contains(name) { return true }
    return name.hasSuffix("Class") || name.hasSuffix("Reference")
}

internal func memoryStructSendableClassMemberUncheckedSendable(_ clause: InheritanceClauseSyntax?) -> Swift.Bool {
    guard let clause else { return false }
    for inherited in clause.inheritedTypes {
        guard let attributed = inherited.type.as(AttributedTypeSyntax.self)
        else { continue }
        var hasUnchecked = false
        for attribute in attributed.attributes {
            if case .attribute(let attr) = attribute,
               let name = attr.attributeName.as(IdentifierTypeSyntax.self),
               name.name.text == "unchecked" {
                hasUnchecked = true
            }
        }
        guard hasUnchecked else { continue }
        if let identifier = attributed.baseType.as(IdentifierTypeSyntax.self),
           identifier.name.text == "Sendable" {
            return true
        }
        if let member = attributed.baseType.as(MemberTypeSyntax.self),
           member.name.text == "Sendable",
           let base = member.baseType.as(IdentifierTypeSyntax.self),
           base.name.text == "Swift" {
            return true
        }
    }
    return false
}

internal func memoryStructSendableClassMemberIsComputed(_ node: VariableDeclSyntax) -> Swift.Bool {
    for binding in node.bindings {
        if let accessors = binding.accessorBlock {
            switch accessors.accessors {
            case .accessors(let list):
                for accessor in list {
                    switch accessor.accessorSpecifier.tokenKind {
                    case .keyword(.get), .keyword(.set):
                        return true
                    default: break
                    }
                }
            case .getter:
                return true
            }
        }
    }
    return false
}

internal final class MemoryStructSendableClassMemberVisitor: SyntaxVisitor {
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
        guard memoryStructSendableClassMemberUncheckedSendable(node.inheritanceClause) else {
            return .visitChildren
        }
        for member in node.memberBlock.members {
            guard let variable = member.decl.as(VariableDeclSyntax.self) else {
                continue
            }
            // Stored properties only.
            if memoryStructSendableClassMemberIsComputed(variable) {
                continue
            }
            for binding in variable.bindings {
                guard let annotation = binding.typeAnnotation else { continue }
                if let identifier = annotation.type.as(IdentifierTypeSyntax.self),
                   memoryStructSendableClassMemberLooksLikeClassType(identifier.name.text) {
                    let location = converter.location(
                        for: variable.bindingSpecifier.positionAfterSkippingLeadingTrivia
                    )
                    matches.append(Diagnostic.Record(
                        location: Source.Location(
                            fileID: source.fileID,
                            filePath: source.filePath,
                            line: location.line,
                            column: location.column
                        ),
                        severity: severity,
                        identifier: "sendable struct with class member",
                        message: memoryStructSendableClassMemberMessage
                    ))
                }
            }
        }
        return .visitChildren
    }
}
