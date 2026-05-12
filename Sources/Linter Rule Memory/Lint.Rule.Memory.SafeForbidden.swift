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

/// Wave 3 Thread 7 (2026-05-11) — the `@safe` attribute MUST NOT
/// appear on any declaration in `Sources/`.
///
/// Wave 4 (2026-05-12, stamped DECISION Option a) — extended with an
/// **absorber-pattern carve-out** on type declarations. The `@safe`
/// attribute MAY appear on a type declaration (struct / class / enum /
/// actor) when BOTH:
///
/// 1. The type's body or attributes contain ≥1 of:
///    a) An `@unsafe` attribute or `@unchecked Sendable` clause on the
///       type itself (extension or inline conformance).
///    b) A `nonisolated(unsafe)` stored property.
///    c) Internal storage of `Unsafe*Pointer<...>` / `OpaquePointer` /
///       `Unmanaged<...>` / raw bytes.
///
/// 2. The type declaration is accompanied by ≥1 of:
///    a) An adjacent `// WHY: Category <A|B|C|D> — <reason>` (or
///       `// SAFETY: Category …`) line citing a `[MEM-SAFE-021..024]`
///       taxonomy entry.
///    b) A `## Safety Invariant` doc-comment section per
///       `[MEM-SAFE-025a]`.
///
/// Citation: `[MEM-SAFE-025b]` (memory-safety skill, safety-isolation.md);
/// Wave 4 DECISION per `swift-foundations/swift-linter-rules/Research/
/// wave-4-absorber-pattern-policy-lean-2026-05-12.md` v1.1.0.
///
/// The institute policy converged on stating encapsulation invariants
/// in adjacent `// SAFETY:` / `// WHY:` prose comments instead of via
/// the `@safe` attribute (SE-0458). Comments are richer (they name
/// the specific invariant) and skill citations are first-class. The
/// absorber-pattern carve-out admits a deliberate institute idiom:
/// when a type encapsulates unsafe storage behind a typed API and
/// declares its invariants explicitly, `@safe` is the type-level
/// pairing for that disclosure.
///
/// Direct `@safe` on funcs / vars / lets / inits / subscripts remains
/// forbidden — `[MEM-SAFE-025a]` invariant comments are the canonical
/// mechanism for those.
extension Lint.Rule {
    public static let `safe attribute forbidden` = Lint.Rule(
        id: "safe attribute forbidden",
        defaultSeverity: .warning,
        findings: { source, severity in
            let visitor = MemorySafeForbiddenVisitor(
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
internal let memorySafeForbiddenMessage: Swift.String =
    "[safe attribute forbidden] [MEM-SAFE-025b]: the `@safe` attribute MUST NOT "
    + "appear in `Sources/`. Express encapsulation invariants as adjacent "
    + "`// SAFETY:` / `// WHY:` comments per [MEM-SAFE-025a] (when adjacent to "
    + "`nonisolated(unsafe)`) or as `## Safety Invariant` doc-comment sections "
    + "per [MEM-SAFE-024] (when adjacent to `@unchecked Sendable` conformances). "
    + "The comment form is richer than the attribute (it names the specific "
    + "invariant and may cite skill rules). "
    + "Carve-out (Wave 4, 2026-05-12): `@safe` on a type declaration is "
    + "permitted when (1) the type's body shows genuine unsafe internals "
    + "(`@unsafe` / `@unchecked Sendable` / `nonisolated(unsafe)` property / "
    + "unsafe pointer storage) AND (2) an adjacent `// WHY: Category <A|B|C|D> "
    + "— ...` line or `## Safety Invariant` doc section discloses the absorber's "
    + "invariant. Both conditions must hold."

internal final class MemorySafeForbiddenVisitor: SyntaxVisitor {
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

    // MARK: - @safe attribute detection

    /// Returns the first `@safe` attribute syntax in `attributes`,
    /// or `nil` if none is present. Used as both the gate and the
    /// finding-location source.
    private func safeAttribute(in attributes: AttributeListSyntax) -> AttributeSyntax? {
        for attribute in attributes {
            guard let attr = attribute.as(AttributeSyntax.self) else { continue }
            if attr.attributeName.trimmedDescription == "safe" {
                return attr
            }
        }
        return nil
    }

    private func emit(at attribute: AttributeSyntax) {
        let location = converter.location(for: attribute.positionAfterSkippingLeadingTrivia)
        matches.append(Diagnostic.Record(
            location: Source.Location(
                fileID: source.fileID,
                filePath: source.filePath,
                line: location.line,
                column: location.column
            ),
            severity: severity,
            identifier: "safe attribute forbidden",
            message: memorySafeForbiddenMessage
        ))
    }

    // MARK: - Absorber-pattern carve-out predicate

    /// Returns `true` when BOTH carve-out conditions hold for the given
    /// type declaration.
    private func absorberPatternCarveOutApplies(
        attributes: AttributeListSyntax,
        inheritanceClause: InheritanceClauseSyntax?,
        memberBlock: MemberBlockSyntax,
        node: any DeclSyntaxProtocol,
        keywordToken: TokenSyntax,
        siblings: SiblingScanResult
    ) -> Bool {
        let condition1 = hasUnsafeAttributeOrUncheckedSendable(
            attributes: attributes,
            inheritanceClause: inheritanceClause,
            siblings: siblings
        )
            || hasNonisolatedUnsafeStoredProperty(memberBlock)
            || hasUnsafePointerStorage(memberBlock)
        guard condition1 else { return false }

        // The invariant disclosure may sit:
        //   - In the decl's leading trivia (BEFORE `@safe`).
        //   - Between `@safe` and the next attribute/modifier (in the
        //     leading trivia of `public` / the type keyword).
        //
        // We check each token's leading trivia from the decl's start
        // to the keyword token. Each token's trivia is checked
        // INDEPENDENTLY for adjacency — we don't merge them, because
        // the `newlines(N)` count is only meaningful within a single
        // contiguous trivia block.
        for trivia in adjacentTriviaBlocks(node: node, keywordToken: keywordToken) {
            if triviaHasWhyCategoryLine(trivia)
                || triviaHasSafetyInvariantDocSection(trivia) {
                return true
            }
        }
        return false
    }

    /// Collect the leading trivia of each token from the decl's first
    /// token to the keyword token (inclusive). Each block is a
    /// coherent SwiftSyntax `Trivia` value with its own newline
    /// counts; we never merge across blocks.
    private func adjacentTriviaBlocks(
        node: any DeclSyntaxProtocol,
        keywordToken: TokenSyntax
    ) -> [Trivia] {
        var blocks: [Trivia] = []
        for token in node.tokens(viewMode: .sourceAccurate) {
            blocks.append(token.leadingTrivia)
            if token == keywordToken { break }
        }
        return blocks
    }

    // MARK: - Condition 1 helpers

    /// True if `attributes` includes `@unsafe`, OR the inheritance
    /// clause / a sibling extension declares `@unchecked Sendable`.
    private func hasUnsafeAttributeOrUncheckedSendable(
        attributes: AttributeListSyntax,
        inheritanceClause: InheritanceClauseSyntax?,
        siblings: SiblingScanResult
    ) -> Bool {
        // `@unsafe` attribute on the type itself.
        for attribute in attributes {
            guard let attr = attribute.as(AttributeSyntax.self) else { continue }
            if attr.attributeName.trimmedDescription == "unsafe" {
                return true
            }
        }
        // `: @unchecked Sendable` (or `@unsafe @unchecked Sendable`)
        // in the inline inheritance clause.
        if let inheritanceClause {
            for inherited in inheritanceClause.inheritedTypes {
                if inheritedTypeIsUncheckedSendable(inherited) {
                    return true
                }
            }
        }
        // Sibling extension `extension <TypeName>: @unchecked Sendable`.
        if siblings.hasUncheckedSendableExtension {
            return true
        }
        return false
    }

    /// Match `: @unchecked Sendable` and `: @unsafe @unchecked
    /// Sendable` (and similar shapes) on a single inherited type
    /// entry.
    private func inheritedTypeIsUncheckedSendable(_ inherited: InheritedTypeSyntax) -> Bool {
        // `inherited.type` is a TypeSyntaxProtocol. For the
        // `@unchecked Sendable` shape SwiftSyntax represents the
        // attribute as part of the type. We trim the description and
        // look for the literal `@unchecked Sendable`.
        let description = inherited.type.trimmedDescription
        return description.contains("@unchecked") && description.contains("Sendable")
    }

    /// True if any stored property in the member block carries the
    /// `nonisolated(unsafe)` modifier.
    private func hasNonisolatedUnsafeStoredProperty(_ memberBlock: MemberBlockSyntax) -> Bool {
        for member in memberBlock.members {
            guard let variable = member.decl.as(VariableDeclSyntax.self) else { continue }
            for modifier in variable.modifiers {
                if modifier.name.tokenKind == .keyword(.nonisolated) {
                    if let detail = modifier.detail, detail.detail.text == "unsafe" {
                        return true
                    }
                }
            }
        }
        return false
    }

    /// True if any stored property has an unsafe-pointer-family type:
    /// `Unsafe*Pointer<…>`, `OpaquePointer`, `Unmanaged<…>`.
    private func hasUnsafePointerStorage(_ memberBlock: MemberBlockSyntax) -> Bool {
        for member in memberBlock.members {
            guard let variable = member.decl.as(VariableDeclSyntax.self) else { continue }
            for binding in variable.bindings {
                if let typeAnnotation = binding.typeAnnotation,
                   typeContainsUnsafePointer(typeAnnotation.type) {
                    return true
                }
            }
        }
        return false
    }

    private static let unsafeTypeIdentifiers: Set<Swift.String> = [
        "UnsafePointer",
        "UnsafeMutablePointer",
        "UnsafeRawPointer",
        "UnsafeMutableRawPointer",
        "UnsafeBufferPointer",
        "UnsafeMutableBufferPointer",
        "UnsafeRawBufferPointer",
        "UnsafeMutableRawBufferPointer",
        "OpaquePointer",
        "Unmanaged",
    ]

    /// Walk a type syntax tree looking for any identifier in the
    /// unsafe-pointer family. Handles generics (`UnsafePointer<UInt8>`),
    /// optionals (`UnsafePointer<…>?`), tuples, and nested type
    /// references.
    private func typeContainsUnsafePointer(_ type: TypeSyntax) -> Bool {
        if let identifier = type.as(IdentifierTypeSyntax.self) {
            if Self.unsafeTypeIdentifiers.contains(identifier.name.text) {
                return true
            }
            if let genericArguments = identifier.genericArgumentClause {
                for argument in genericArguments.arguments {
                    if case let .type(argumentType) = argument.argument,
                       typeContainsUnsafePointer(argumentType) {
                        return true
                    }
                }
            }
            return false
        }
        if let optional = type.as(OptionalTypeSyntax.self) {
            return typeContainsUnsafePointer(optional.wrappedType)
        }
        if let implicitlyUnwrapped = type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
            return typeContainsUnsafePointer(implicitlyUnwrapped.wrappedType)
        }
        if let memberType = type.as(MemberTypeSyntax.self) {
            // `Swift.UnsafePointer<…>` — check the right-most segment.
            if Self.unsafeTypeIdentifiers.contains(memberType.name.text) {
                return true
            }
            if let genericArguments = memberType.genericArgumentClause {
                for argument in genericArguments.arguments {
                    if case let .type(argumentType) = argument.argument,
                       typeContainsUnsafePointer(argumentType) {
                        return true
                    }
                }
            }
            return false
        }
        if let tuple = type.as(TupleTypeSyntax.self) {
            for element in tuple.elements {
                if typeContainsUnsafePointer(element.type) {
                    return true
                }
            }
            return false
        }
        if let attributed = type.as(AttributedTypeSyntax.self) {
            return typeContainsUnsafePointer(attributed.baseType)
        }
        return false
    }

    // MARK: - Condition 2 helpers

    /// True if the trivia contains a `// WHY:` or `// SAFETY:` line
    /// that names a Category A/B/C/D and sits in an adjacent comment
    /// block (no blank line between the block and the declaration
    /// keyword).
    ///
    /// "Adjacent" means: walking BACKWARDS from the end of the trivia
    /// (closest-to-keyword first), we collect all line comments that
    /// appear in a contiguous block (no blank line — i.e., no piece
    /// with `newlines(count) >= 2` — interposed). If ANY line in the
    /// block matches `// {WHY|SAFETY}: ... Category <A|B|C|D> ...`,
    /// the predicate passes.
    ///
    /// Non-invariant comments (`// WHEN TO REMOVE:`, `// TRACKING:`,
    /// etc.) are permitted within the adjacent block. The institute
    /// idiom for absorber types is to attach a `// WHY: Category …`
    /// disclosure alongside metadata comments; the carve-out admits
    /// that complete idiom.
    private func triviaHasWhyCategoryLine(_ trivia: Trivia) -> Bool {
        let pieces = Swift.Array(trivia)
        for piece in pieces.reversed() {
            switch piece {
            case .newlines(let count):
                if count >= 2 { return false }
            case .carriageReturns(let count), .carriageReturnLineFeeds(let count):
                if count >= 2 { return false }
            case .lineComment(let text):
                let body = stripCommentPrefix(text)
                if isInvariantPrefix(body) && containsCategoryCitation(body) {
                    return true
                }
                // Non-invariant line comment — keep walking, the
                // `// WHY:` line might be earlier in the contiguous
                // block.
                continue
            case .docLineComment, .docBlockComment, .blockComment:
                // Doc / block comments are not the WHY-line form.
                // They might satisfy the
                // `Safety Invariant`-doc-section branch (handled
                // separately). Don't treat as adjacency boundary —
                // keep walking.
                continue
            case .spaces, .tabs:
                continue
            default:
                continue
            }
        }
        return false
    }

    /// Drop the leading `//` and any horizontal whitespace.
    private func stripCommentPrefix(_ text: Swift.String) -> Swift.Substring {
        let trimmed = text.trimmingPrefix("//")
        return trimmed.drop(while: { $0 == " " || $0 == "\t" })
    }

    /// `true` if the comment body begins with `WHY:` or `SAFETY:`
    /// (case-insensitive on the keyword).
    private func isInvariantPrefix(_ body: Swift.Substring) -> Bool {
        let lower = body.lowercased()
        return lower.hasPrefix("why:") || lower.hasPrefix("safety:")
    }

    /// `true` if the comment body cites `Category <A|B|C|D>` (with a
    /// word boundary after the letter — guards against "Category E"
    /// or "Categorical").
    private func containsCategoryCitation(_ body: Swift.Substring) -> Bool {
        // Linear scan for "Category " followed by one of A/B/C/D and
        // a non-letter / non-digit boundary. Avoids importing Regex
        // (overkill for one literal pattern); stays AST/string-only.
        let lower = body.lowercased()
        let needle = "category "
        var cursor = lower.startIndex
        while cursor < lower.endIndex {
            guard let range = lower[cursor...].range(of: needle) else { return false }
            let after = range.upperBound
            guard after < lower.endIndex else {
                cursor = range.upperBound
                continue
            }
            let categoryChar = lower[after]
            if "abcd".contains(categoryChar) {
                // Boundary check on the character AFTER the letter.
                let next = lower.index(after: after)
                if next == lower.endIndex {
                    return true
                }
                let boundaryChar = lower[next]
                if !(boundaryChar.isLetter || boundaryChar.isNumber) {
                    return true
                }
            }
            cursor = range.upperBound
        }
        return false
    }

    /// True if the trivia contains a doc-comment section with the
    /// literal heading `## Safety Invariant`. A blank line (a single
    /// `newlines(N)` piece with `N >= 2`) between the doc block and
    /// the rest of the trivia breaks adjacency.
    ///
    /// Non-doc line comments (`// WHEN TO REMOVE:` etc.) are tolerated
    /// in the adjacent block — the institute idiom mixes both.
    private func triviaHasSafetyInvariantDocSection(_ trivia: Trivia) -> Bool {
        let pieces = Swift.Array(trivia)
        var collected: [Swift.String] = []

        for piece in pieces.reversed() {
            switch piece {
            case .newlines(let count):
                if count >= 2 {
                    return matchesSafetyInvariant(in: collected)
                }
            case .carriageReturns(let count), .carriageReturnLineFeeds(let count):
                if count >= 2 {
                    return matchesSafetyInvariant(in: collected)
                }
            case .docLineComment(let text):
                collected.append(text)
            case .docBlockComment(let text):
                collected.append(text)
            case .lineComment, .blockComment:
                // Non-doc comments are tolerated — keep walking, the
                // doc-block might be earlier.
                continue
            case .spaces, .tabs:
                continue
            default:
                continue
            }
        }
        return matchesSafetyInvariant(in: collected)
    }

    private func matchesSafetyInvariant(in pieces: [Swift.String]) -> Bool {
        for text in pieces {
            if text.contains("## Safety Invariant") {
                return true
            }
        }
        return false
    }

    // MARK: - Sibling extension scan

    /// Result of scanning the file for `extension <T>: @unchecked
    /// Sendable {}` adjacent to a type decl named `T`.
    internal struct SiblingScanResult {
        let hasUncheckedSendableExtension: Bool
    }

    /// Scan the enclosing source file for any extension of `typeName`
    /// that adds `@unchecked Sendable` conformance.
    private func scanSiblingsForUncheckedSendable(
        typeName: Swift.String,
        within node: any DeclSyntaxProtocol
    ) -> SiblingScanResult {
        // Walk to the SourceFileSyntax root.
        var current: Syntax = Syntax(node)
        while let parent = current.parent {
            current = parent
        }
        guard let sourceFile = current.as(SourceFileSyntax.self) else {
            return SiblingScanResult(hasUncheckedSendableExtension: false)
        }
        var found = false
        for statement in sourceFile.statements {
            guard let ext = statement.item.as(ExtensionDeclSyntax.self) else { continue }
            // Strip generic arguments from the extended type — the
            // institute pattern is `extension <Type>` not `extension
            // <Type><GArg>` for Sendable conformances. Compare by
            // trimmed-name match (best-effort, sufficient for the
            // common case).
            let extended = ext.extendedType.trimmedDescription
            // Accept either exact match or "<typeName>.<…>" (nested
            // accessors don't typically appear here, but defensive).
            let matchesName = (extended == typeName)
                || extended.hasPrefix(typeName + ".")
                || extended.hasPrefix(typeName + "<")
            guard matchesName else { continue }
            if let inheritance = ext.inheritanceClause {
                for inherited in inheritance.inheritedTypes {
                    if inheritedTypeIsUncheckedSendable(inherited) {
                        found = true
                    }
                }
            }
        }
        return SiblingScanResult(hasUncheckedSendableExtension: found)
    }

    // MARK: - Type-decl visitors (carve-out eligible)

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let safeAttr = safeAttribute(in: node.attributes) else {
            return .visitChildren
        }
        let siblings = scanSiblingsForUncheckedSendable(typeName: node.name.text, within: node)
        if absorberPatternCarveOutApplies(
            attributes: node.attributes,
            inheritanceClause: node.inheritanceClause,
            memberBlock: node.memberBlock,
            node: node,
            keywordToken: node.structKeyword,
            siblings: siblings
        ) {
            return .visitChildren
        }
        emit(at: safeAttr)
        return .visitChildren
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let safeAttr = safeAttribute(in: node.attributes) else {
            return .visitChildren
        }
        let siblings = scanSiblingsForUncheckedSendable(typeName: node.name.text, within: node)
        if absorberPatternCarveOutApplies(
            attributes: node.attributes,
            inheritanceClause: node.inheritanceClause,
            memberBlock: node.memberBlock,
            node: node,
            keywordToken: node.classKeyword,
            siblings: siblings
        ) {
            return .visitChildren
        }
        emit(at: safeAttr)
        return .visitChildren
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let safeAttr = safeAttribute(in: node.attributes) else {
            return .visitChildren
        }
        let siblings = scanSiblingsForUncheckedSendable(typeName: node.name.text, within: node)
        if absorberPatternCarveOutApplies(
            attributes: node.attributes,
            inheritanceClause: node.inheritanceClause,
            memberBlock: node.memberBlock,
            node: node,
            keywordToken: node.enumKeyword,
            siblings: siblings
        ) {
            return .visitChildren
        }
        emit(at: safeAttr)
        return .visitChildren
    }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let safeAttr = safeAttribute(in: node.attributes) else {
            return .visitChildren
        }
        let siblings = scanSiblingsForUncheckedSendable(typeName: node.name.text, within: node)
        if absorberPatternCarveOutApplies(
            attributes: node.attributes,
            inheritanceClause: node.inheritanceClause,
            memberBlock: node.memberBlock,
            node: node,
            keywordToken: node.actorKeyword,
            siblings: siblings
        ) {
            return .visitChildren
        }
        emit(at: safeAttr)
        return .visitChildren
    }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        // Extensions are NOT eligible for the carve-out — they don't
        // introduce a new type-level absorption boundary. `@safe` on
        // an extension is flagged unconditionally.
        if let safeAttr = safeAttribute(in: node.attributes) {
            emit(at: safeAttr)
        }
        return .visitChildren
    }

    // MARK: - Non-type-decl visitors (carve-out does NOT apply)

    private func recordSafeAttributes(_ attributes: AttributeListSyntax) {
        if let attr = safeAttribute(in: attributes) {
            emit(at: attr)
        }
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        recordSafeAttributes(node.attributes)
        return .visitChildren
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        recordSafeAttributes(node.attributes)
        return .visitChildren
    }

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        recordSafeAttributes(node.attributes)
        return .visitChildren
    }

    override func visit(_ node: DeinitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        recordSafeAttributes(node.attributes)
        return .visitChildren
    }

    override func visit(_ node: SubscriptDeclSyntax) -> SyntaxVisitorContinueKind {
        recordSafeAttributes(node.attributes)
        return .visitChildren
    }

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        recordSafeAttributes(node.attributes)
        return .visitChildren
    }

    override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        recordSafeAttributes(node.attributes)
        return .visitChildren
    }

    override func visit(_ node: AssociatedTypeDeclSyntax) -> SyntaxVisitorContinueKind {
        recordSafeAttributes(node.attributes)
        return .visitChildren
    }
}
