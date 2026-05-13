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

/// Flags `A & B` compositions where `A` already refines `B` in the
/// standard library. The `& B` half is redundant — the compiler enforces
/// `B` through `A`'s refinement chain.
///
/// Citation: experiment `swift-institute/Experiments/error-implies-sendable`
/// (CONFIRMED 2026-05-13) — `Swift.Error` refines `Swift.Sendable` in
/// Swift 6 mode; spelling `Error & Sendable` in generic constraints,
/// conformance clauses, or existentials adds no information. The same
/// pattern applies to all stdlib refinement pairs in the table below.
///
/// Scope: the rule is purely syntactic, driven by a refinement table.
/// Adding new refinement pairs to `idiomKnownStdlibRefinements` is the
/// supported extension point today.
///
/// The fully general "any A & B where A refines B" form does NOT require
/// a live type-resolution backend: the precomputed-oracle path
/// (Shape F in `swift-foundations/swift-linter/Research/
/// lsp-sourcekit-integration.md` v1.1.0) is empirically viable — see
/// `swift-foundations/swift-json/Experiments/
/// symbol-graph-conformance-oracle/` (CONFIRMED 2026-05-13), which
/// extracted 136 protocol-protocol refinement pairs from Swift stdlib's
/// `swift-symbolgraph-extract` output, reproducing all 26 entries of
/// this hardcoded table plus 110 additional refinements. Phase 2
/// production work would bundle the extraction step into the linter
/// cohort's release pipeline; the rule's predicate stays AST-only.
extension Lint.Rule {
    public static let `redundant refinement` = Lint.Rule(
        id: "redundant refinement",
        default: .warning,
        findings: { source, severity in
            let visitor = IdiomRedundantRefinementVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.walk(source.tree)
            return visitor.matches
        }
    )
}

/// Known stdlib protocol refinements: each pair `(refining, refined)`
/// means `refining` declares `: refined` in the standard library
/// (directly or transitively), so a composition `refining & refined`
/// (in either order) is redundant.
///
/// Sourcing: extracted from Swift 6.3.1 stdlib's symbol graph via
/// `swift-foundations/swift-json/Experiments/symbol-graph-conformance-oracle/`
/// (CONFIRMED 2026-05-13). The set is the transitive closure of
/// protocol→protocol `conformsTo` relationships emitted by
/// `swift-symbolgraph-extract -module-name Swift`. The empirically-
/// derived form (136 pairs) supersedes the prior hand-curated form
/// (26 pairs) — every original entry is preserved; the additional 110
/// entries cover the transitive closure across the towers plus
/// previously-omitted protocol families (`OptionSet`, `SetAlgebra`,
/// `SIMD`, `SIMDScalar`, `StringProtocol`, `CodingKey`,
/// `DurationProtocol`, `InstantProtocol`, the `ExpressibleBy*`
/// hierarchy, `SendableMetatype`/`UnsafeSendable`,
/// `LosslessStringConvertible`, `CustomLeafReflectable`).
///
/// Regeneration: rerun the experiment package against the active
/// toolchain when stdlib protocols change (typically once per Swift
/// minor release). The extraction is one command + one binary run;
/// see the experiment's `main.swift` header for the exact recipe.
@usableFromInline
internal let idiomKnownStdlibRefinements: [(refining: Swift.String, refined: Swift.String)] = [
    // MARK: - Sendable family

    ("Error", "Sendable"),
    ("Error", "SendableMetatype"),
    ("Sendable", "SendableMetatype"),
    ("UnsafeSendable", "Sendable"),
    ("UnsafeSendable", "SendableMetatype"),

    // MARK: - Equatable chain

    ("AdditiveArithmetic", "Equatable"),
    ("Comparable", "Equatable"),
    ("Hashable", "Equatable"),

    // MARK: - Strideable

    ("Strideable", "Comparable"),
    ("Strideable", "Equatable"),

    // MARK: - Numeric tower (direct + transitive)

    ("Numeric", "AdditiveArithmetic"),
    ("Numeric", "Equatable"),
    ("Numeric", "ExpressibleByIntegerLiteral"),
    ("SignedNumeric", "AdditiveArithmetic"),
    ("SignedNumeric", "Equatable"),
    ("SignedNumeric", "ExpressibleByIntegerLiteral"),
    ("SignedNumeric", "Numeric"),
    ("BinaryInteger", "AdditiveArithmetic"),
    ("BinaryInteger", "Comparable"),
    ("BinaryInteger", "CustomStringConvertible"),
    ("BinaryInteger", "Equatable"),
    ("BinaryInteger", "ExpressibleByIntegerLiteral"),
    ("BinaryInteger", "Hashable"),
    ("BinaryInteger", "Numeric"),
    ("BinaryInteger", "Strideable"),
    ("FixedWidthInteger", "AdditiveArithmetic"),
    ("FixedWidthInteger", "BinaryInteger"),
    ("FixedWidthInteger", "Comparable"),
    ("FixedWidthInteger", "CustomStringConvertible"),
    ("FixedWidthInteger", "Equatable"),
    ("FixedWidthInteger", "ExpressibleByIntegerLiteral"),
    ("FixedWidthInteger", "Hashable"),
    ("FixedWidthInteger", "LosslessStringConvertible"),
    ("FixedWidthInteger", "Numeric"),
    ("FixedWidthInteger", "Strideable"),
    ("SignedInteger", "AdditiveArithmetic"),
    ("SignedInteger", "BinaryInteger"),
    ("SignedInteger", "Comparable"),
    ("SignedInteger", "CustomStringConvertible"),
    ("SignedInteger", "Equatable"),
    ("SignedInteger", "ExpressibleByIntegerLiteral"),
    ("SignedInteger", "Hashable"),
    ("SignedInteger", "Numeric"),
    ("SignedInteger", "SignedNumeric"),
    ("SignedInteger", "Strideable"),
    ("UnsignedInteger", "AdditiveArithmetic"),
    ("UnsignedInteger", "BinaryInteger"),
    ("UnsignedInteger", "Comparable"),
    ("UnsignedInteger", "CustomStringConvertible"),
    ("UnsignedInteger", "Equatable"),
    ("UnsignedInteger", "ExpressibleByIntegerLiteral"),
    ("UnsignedInteger", "Hashable"),
    ("UnsignedInteger", "Numeric"),
    ("UnsignedInteger", "Strideable"),

    // MARK: - FloatingPoint tower (direct + transitive)

    ("FloatingPoint", "AdditiveArithmetic"),
    ("FloatingPoint", "Comparable"),
    ("FloatingPoint", "Equatable"),
    ("FloatingPoint", "ExpressibleByIntegerLiteral"),
    ("FloatingPoint", "Hashable"),
    ("FloatingPoint", "Numeric"),
    ("FloatingPoint", "SignedNumeric"),
    ("FloatingPoint", "Strideable"),
    ("BinaryFloatingPoint", "AdditiveArithmetic"),
    ("BinaryFloatingPoint", "Comparable"),
    ("BinaryFloatingPoint", "Equatable"),
    ("BinaryFloatingPoint", "ExpressibleByFloatLiteral"),
    ("BinaryFloatingPoint", "ExpressibleByIntegerLiteral"),
    ("BinaryFloatingPoint", "FloatingPoint"),
    ("BinaryFloatingPoint", "Hashable"),
    ("BinaryFloatingPoint", "Numeric"),
    ("BinaryFloatingPoint", "SignedNumeric"),
    ("BinaryFloatingPoint", "Strideable"),

    // MARK: - Sequence / Collection tower (direct + transitive)

    ("Collection", "Sequence"),
    ("BidirectionalCollection", "Collection"),
    ("BidirectionalCollection", "Sequence"),
    ("MutableCollection", "Collection"),
    ("MutableCollection", "Sequence"),
    ("RandomAccessCollection", "BidirectionalCollection"),
    ("RandomAccessCollection", "Collection"),
    ("RandomAccessCollection", "Sequence"),
    ("RangeReplaceableCollection", "Collection"),
    ("RangeReplaceableCollection", "Sequence"),
    ("LazySequenceProtocol", "Sequence"),
    ("LazyCollectionProtocol", "Collection"),
    ("LazyCollectionProtocol", "LazySequenceProtocol"),
    ("LazyCollectionProtocol", "Sequence"),

    // MARK: - StringProtocol

    ("StringProtocol", "BidirectionalCollection"),
    ("StringProtocol", "Collection"),
    ("StringProtocol", "Comparable"),
    ("StringProtocol", "CustomStringConvertible"),
    ("StringProtocol", "Equatable"),
    ("StringProtocol", "ExpressibleByExtendedGraphemeClusterLiteral"),
    ("StringProtocol", "ExpressibleByStringInterpolation"),
    ("StringProtocol", "ExpressibleByStringLiteral"),
    ("StringProtocol", "ExpressibleByUnicodeScalarLiteral"),
    ("StringProtocol", "Hashable"),
    ("StringProtocol", "LosslessStringConvertible"),
    ("StringProtocol", "Sequence"),
    ("StringProtocol", "TextOutputStream"),
    ("StringProtocol", "TextOutputStreamable"),

    // MARK: - ExpressibleBy* literal hierarchy

    ("ExpressibleByExtendedGraphemeClusterLiteral", "ExpressibleByUnicodeScalarLiteral"),
    ("ExpressibleByStringInterpolation", "ExpressibleByExtendedGraphemeClusterLiteral"),
    ("ExpressibleByStringInterpolation", "ExpressibleByStringLiteral"),
    ("ExpressibleByStringInterpolation", "ExpressibleByUnicodeScalarLiteral"),
    ("ExpressibleByStringLiteral", "ExpressibleByExtendedGraphemeClusterLiteral"),
    ("ExpressibleByStringLiteral", "ExpressibleByUnicodeScalarLiteral"),

    // MARK: - Coding

    ("CodingKey", "CustomDebugStringConvertible"),
    ("CodingKey", "CustomStringConvertible"),
    ("CodingKey", "Sendable"),
    ("CodingKey", "SendableMetatype"),

    // MARK: - Duration / Instant

    ("DurationProtocol", "AdditiveArithmetic"),
    ("DurationProtocol", "Comparable"),
    ("DurationProtocol", "Equatable"),
    ("DurationProtocol", "Sendable"),
    ("DurationProtocol", "SendableMetatype"),
    ("InstantProtocol", "Comparable"),
    ("InstantProtocol", "Equatable"),
    ("InstantProtocol", "Hashable"),
    ("InstantProtocol", "Sendable"),
    ("InstantProtocol", "SendableMetatype"),

    // MARK: - OptionSet / SetAlgebra

    ("OptionSet", "Equatable"),
    ("OptionSet", "ExpressibleByArrayLiteral"),
    ("OptionSet", "RawRepresentable"),
    ("OptionSet", "SetAlgebra"),
    ("SetAlgebra", "Equatable"),
    ("SetAlgebra", "ExpressibleByArrayLiteral"),

    // MARK: - SIMD

    ("SIMD", "CustomStringConvertible"),
    ("SIMD", "Decodable"),
    ("SIMD", "Encodable"),
    ("SIMD", "Equatable"),
    ("SIMD", "ExpressibleByArrayLiteral"),
    ("SIMD", "Hashable"),
    ("SIMD", "SIMDStorage"),
    ("SIMDScalar", "BitwiseCopyable"),

    // MARK: - Other singletons

    ("CustomLeafReflectable", "CustomReflectable"),
    ("LosslessStringConvertible", "CustomStringConvertible"),
]

@usableFromInline
internal func idiomRedundantRefinementMessage(
    refining: Swift.String,
    refined: Swift.String
) -> Swift.String {
    "[redundant refinement] feedback_redundant_protocol_refinement: "
    + "`\(refining) & \(refined)` — `\(refining)` already refines `\(refined)` "
    + "in the standard library. The `& \(refined)` half is redundant; "
    + "the compiler enforces `\(refined)` through `\(refining)`. Drop "
    + "the redundant member."
}

internal final class IdiomRedundantRefinementVisitor: SyntaxVisitor {
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

    override func visit(_ node: CompositionTypeSyntax) -> SyntaxVisitorContinueKind {
        // Collect the leaf identifier of each element + its position. Skip
        // elements with no leaf name (suppressed types like ~Copyable,
        // anonymous structural types, etc.).
        var leaves: [(name: Swift.String, position: AbsolutePosition)] = []
        for element in node.elements {
            if let name = leafName(of: element.type) {
                leaves.append((name, element.type.positionAfterSkippingLeadingTrivia))
            }
        }
        // For each ordered pair (i, j), check whether leaves[i] refines
        // leaves[j]. Report at the position of the redundant (refined)
        // leaf — that's the member to delete.
        var reportedPositions: Swift.Set<AbsolutePosition> = []
        for i in 0..<leaves.count {
            for j in 0..<leaves.count where i != j {
                let refining = leaves[i].name
                let refined = leaves[j].name
                let isRedundant = idiomKnownStdlibRefinements.contains { pair in
                    pair.refining == refining && pair.refined == refined
                }
                guard isRedundant else { continue }
                let position = leaves[j].position
                guard !reportedPositions.contains(position) else { continue }
                reportedPositions.insert(position)
                let location = converter.location(for: position)
                matches.append(Diagnostic.Record(
                    location: Source.Location(
                        fileID: source.fileID,
                        filePath: source.filePath,
                        line: location.line,
                        column: location.column
                    ),
                    severity: severity,
                    identifier: "redundant refinement",
                    message: idiomRedundantRefinementMessage(
                        refining: refining,
                        refined: refined
                    )
                ))
            }
        }
        return .visitChildren
    }

    /// Returns the rightmost identifier of a type expression — e.g.
    /// `Swift.Error` → `Error`, `Error` → `Error`. Existential `any P`
    /// and `some P` unwrap to their constraint. Suppression types
    /// (`~Copyable`) and structural types return nil so they cannot
    /// shadow a real refinement-table entry.
    private func leafName(of type: TypeSyntax) -> Swift.String? {
        if let identifier = type.as(IdentifierTypeSyntax.self) {
            return identifier.name.text
        }
        if let member = type.as(MemberTypeSyntax.self) {
            return member.name.text
        }
        if let some = type.as(SomeOrAnyTypeSyntax.self) {
            return leafName(of: some.constraint)
        }
        return nil
    }
}
