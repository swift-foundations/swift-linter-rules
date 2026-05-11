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

/// Wave 3 (mechanization-program) — configuration-bearing parameters
/// MUST sit at the first OR last non-closure position of a signature.
///
/// Citation: `[API-IMPL-014]` (code-surface skill).
///
/// Configuration-bearing parameters — `.Options`, `.Configuration`,
/// `.Context`, or OptionSet types — fall into two semantic roles:
/// PRIMARY input (operation's identity is the configuration → first),
/// or MODIFIER (operation tunes via configuration → last in the
/// non-closure portion). Middle placement is forbidden because SE-0286
/// forward-scan can't match a trailing closure when configuration sits
/// between domain parameters, and it hides the configuration's role.
///
/// AST shape: walk `FunctionDeclSyntax`/`InitializerDeclSyntax`
/// parameter lists. Identify configuration parameters by type-name
/// suffix (`Options`, `Configuration`, `Context`). Compute the index
/// of each configuration parameter among NON-closure parameters; flag
/// if it is neither the first nor the last non-closure index.
///
/// Worked examples (flagged):
///   - `func perform(on target: Target, options: Options, mode: Mode,
///     body: @escaping () -> Void)` — `options` is at non-closure
///     index 1 of 3 (middle); should move to index 0 or 2.
///
/// Worked examples (NOT flagged):
///   - `func perform(on target: Target, options: Options = [], body:
///     @escaping () -> Void)` — `options` at last non-closure position.
///   - `init(_ configuration: Configuration = .default)` — single
///     parameter; first/last is the same index.
///   - `init(id: ID, interest: Interest, flags: Options = [])` —
///     `flags` (Options) at last non-closure index.
extension Lint.Rule.Closure {
    public struct ConfigurationPlacement: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "configuration_parameter_placement"
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

extension Lint.Rule.Closure.ConfigurationPlacement {
    @usableFromInline
    static let message: Swift.String =
        "[configuration_parameter_placement] [API-IMPL-014]: "
        + "configuration-bearing parameters (`Options`, `Configuration`, "
        + "`Context`) MUST sit at first OR last non-closure position. "
        + "Middle placement breaks SE-0286 forward-scan with trailing "
        + "closures and obscures the configuration's role (primary input "
        + "vs. modifier). Move the parameter to position 0 (primary input) "
        + "or to the last non-closure slot (modifier, with a default)."

    static let configurationSuffixes: Swift.Set<Swift.String> = [
        "Options",
        "Configuration",
        "Context",
    ]

    /// Returns true when the parameter's type ends in one of the
    /// configuration suffixes (after stripping optionals and attributes).
    static func isConfigurationType(_ type: TypeSyntax) -> Swift.Bool {
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
                identifier: Lint.Rule.Closure.ConfigurationPlacement.id.underlying,
                message: Lint.Rule.Closure.ConfigurationPlacement.message
            ))
        }

        private func checkParameters(_ parameters: FunctionParameterListSyntax) {
            // Collect the indices (within the parameter list) of all
            // non-closure parameters in declaration order.
            var nonClosureIndices: [Swift.Int] = []
            for (index, parameter) in parameters.enumerated() {
                if !Lint.Rule.Closure.ParameterPosition.isClosureType(parameter.type) {
                    nonClosureIndices.append(index)
                }
            }
            guard nonClosureIndices.count >= 3 else {
                // 0, 1, or 2 non-closure params — first/last covers all
                // valid positions; nothing in "middle" to flag.
                return
            }
            let firstNonClosure = nonClosureIndices.first!
            let lastNonClosure = nonClosureIndices.last!
            for parameter in parameters {
                guard Lint.Rule.Closure.ConfigurationPlacement.isConfigurationType(parameter.type) else {
                    continue
                }
                // Find this parameter's index in the parameter list.
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
}
