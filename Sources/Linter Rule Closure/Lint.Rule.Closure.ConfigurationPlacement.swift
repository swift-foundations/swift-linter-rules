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

/// Configuration-bearing parameters MUST sit at the first OR last
/// non-closure position of a signature. Citation: `[API-IMPL-014]`.
///
/// Configuration-bearing parameters — `.Options`, `.Configuration`,
/// `.Context`, or OptionSet types — fall into two semantic roles:
/// PRIMARY input (operation's identity is the configuration → first),
/// or MODIFIER (operation tunes via configuration → last in the
/// non-closure portion). Middle placement is forbidden because SE-0286
/// forward-scan can't match a trailing closure when configuration sits
/// between domain parameters, and it hides the configuration's role.
extension Lint.Rule {
    public static let `configuration before content` = Lint.Rule(
        id: "configuration before content",
        default: .warning,
        findings: { source, severity in
            let visitor = ClosureConfigurationPlacementVisitor(
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
internal let closureConfigurationPlacementMessage: Swift.String =
    "[configuration before content] [API-IMPL-014]: "
    + "configuration-bearing parameters (`Options`, `Configuration`, "
    + "`Context`) MUST sit at first OR last non-closure position. "
    + "Middle placement breaks SE-0286 forward-scan with trailing "
    + "closures and obscures the configuration's role (primary input "
    + "vs. modifier). Move the parameter to position 0 (primary input) "
    + "or to the last non-closure slot (modifier, with a default)."

internal let configurationSuffixes: Swift.Set<Swift.String> = [
    "Options",
    "Configuration",
    "Context",
]

/// Returns true when the parameter's type ends in one of the
/// configuration suffixes (after stripping optionals and attributes).
internal func isConfigurationType(_ type: TypeSyntax) -> Swift.Bool {
    var current = type
    while let optional = current.as(OptionalTypeSyntax.self) {
        current = optional.wrappedType
    }
    while let iuo = current.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
        current = iuo.wrappedType
    }
    while let attributed = current.as(AttributedTypeSyntax.self) {
        current = attributed.baseType
    }
    if let identifier = current.as(IdentifierTypeSyntax.self) {
        return configurationSuffixes.contains(identifier.name.text)
    }
    if let member = current.as(MemberTypeSyntax.self) {
        return configurationSuffixes.contains(member.name.text)
    }
    return false
}

internal final class ClosureConfigurationPlacementVisitor: SyntaxVisitor {
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
            identifier: "configuration before content",
            message: closureConfigurationPlacementMessage
        ))
    }

    private func checkParameters(_ parameters: FunctionParameterListSyntax) {
        var nonClosureIndices: [Swift.Int] = []
        for (index, parameter) in parameters.enumerated() {
            if !isClosureType(parameter.type) {
                nonClosureIndices.append(index)
            }
        }
        guard nonClosureIndices.count >= 3 else { return }
        let firstNonClosure = nonClosureIndices.first!
        let lastNonClosure = nonClosureIndices.last!
        for parameter in parameters {
            guard isConfigurationType(parameter.type) else { continue }
            let parameterIndex = parameters.firstIndex(where: { $0.id == parameter.id })
            guard let parameterIndex else { continue }
            let intIndex = parameters.distance(from: parameters.startIndex, to: parameterIndex)
            if intIndex == firstNonClosure || intIndex == lastNonClosure {
                continue
            }
            emit(at: parameter.firstName.positionAfterSkippingLeadingTrivia)
        }
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        checkParameters(node.signature.parameterClause.parameters)
        return .visitChildren
    }

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        checkParameters(node.signature.parameterClause.parameters)
        return .visitChildren
    }
}
