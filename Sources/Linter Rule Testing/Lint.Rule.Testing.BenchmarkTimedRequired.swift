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

/// Wave 2b finalization (2026-05-10) — performance-suite `@Test`
/// functions MUST carry the `.timed()` trait.
///
/// Citation: `[BENCH-003]` (benchmark skill).
///
/// Performance tests use the swift-testing `.timed()` trait for
/// structured measurement: it controls iterations, warmup, threshold,
/// and metric. A `@Test` function inside an `@Suite(.serialized)
/// struct Performance` that is missing `.timed()` produces a one-shot
/// untimed run — defeats the purpose of having a Performance suite.
///
/// AST shape: `FunctionDeclSyntax` whose attributes contain `@Test`
/// AND whose enclosing nominal-type chain reaches a `struct
/// Performance`. The `@Test` attribute's argument list MUST mention
/// `.timed`. If absent, the function name is flagged.
extension Lint.Rule.Testing {
    public struct BenchmarkTimedRequired: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "benchmark_timed_required"
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

extension Lint.Rule.Testing.BenchmarkTimedRequired {
    @usableFromInline
    static let message: Swift.String =
        "[benchmark_timed_required] [BENCH-003]: `@Test` functions inside a "
        + "`Performance` suite MUST carry the `.timed()` trait. Without it, the "
        + "performance test runs once with no measurement structure — iterations, "
        + "warmup, and threshold are all default-skipped. Add `@Test(.timed())` or "
        + "`@Test(.timed(threshold: .milliseconds(N)))` per the suite's budget."

    final class Visitor: SyntaxVisitor {
        let source: Source.File
        let severity: Diagnostic.Severity
        let converter: SourceLocationConverter
        var matches: [Diagnostic.Record] = []
        var inPerformanceStructDepth: Int = 0

        init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
            self.source = source
            self.severity = severity
            self.converter = converter
            super.init(viewMode: .sourceAccurate)
        }

        private func testAttribute(_ attributes: AttributeListSyntax) -> AttributeSyntax? {
            for attribute in attributes {
                guard let attr = attribute.as(AttributeSyntax.self) else { continue }
                if attr.attributeName.trimmedDescription == "Test" {
                    return attr
                }
            }
            return nil
        }

        override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
            if node.name.text == "Performance" {
                inPerformanceStructDepth += 1
            }
            return .visitChildren
        }

        override func visitPost(_ node: StructDeclSyntax) {
            if node.name.text == "Performance" {
                inPerformanceStructDepth -= 1
            }
        }

        override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
            // Recognise `extension Foo.Test.Performance` and similar — if
            // the extended type's last segment is `Performance`, treat the
            // body as performance-suite scope.
            if let last = node.extendedType.trimmedDescription.split(separator: ".").last,
               String(last) == "Performance"
            {
                inPerformanceStructDepth += 1
            }
            return .visitChildren
        }

        override func visitPost(_ node: ExtensionDeclSyntax) {
            if let last = node.extendedType.trimmedDescription.split(separator: ".").last,
               String(last) == "Performance"
            {
                inPerformanceStructDepth -= 1
            }
        }

        override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
            guard inPerformanceStructDepth > 0 else {
                return .visitChildren
            }
            guard let attribute = testAttribute(node.attributes) else {
                return .visitChildren
            }
            // The attribute description includes its arguments; check for `.timed`.
            if !attribute.trimmedDescription.contains(".timed") {
                let location = converter.location(for: node.name.positionAfterSkippingLeadingTrivia)
                matches.append(Diagnostic.Record(
                    location: Source.Location(
                        fileID: source.fileID,
                        filePath: source.filePath,
                        line: location.line,
                        column: location.column
                    ),
                    severity: severity,
                    identifier: Lint.Rule.Testing.BenchmarkTimedRequired.id.underlying,
                    message: Lint.Rule.Testing.BenchmarkTimedRequired.message
                ))
            }
            return .visitChildren
        }
    }
}
