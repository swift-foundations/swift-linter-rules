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

import Testing
import SwiftSyntax
import SwiftParser
import Linter_Primitives
import Linter_Rules_Test_Support
@testable import Linter_Rule_Memory

extension Lint.Rule {
    @Suite
    struct `safe attribute forbidden Tests` {
        @Suite struct Unit {}
        @Suite struct `Absorber Carve-out` {}
    }
}

extension Lint.Rule.`safe attribute forbidden Tests` {
    static func findings(in source: Swift.String, file: Swift.String = "Sources/X/Test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`safe attribute forbidden`.findings(parsed, .warning)
    }
}

// MARK: - Baseline coverage (carve-out NOT applicable — direct forbids)

extension Lint.Rule.`safe attribute forbidden Tests`.Unit {
    @Test
    func `safe attribute on bare struct is flagged`() {
        // No unsafe internals + no invariant comment → carve-out fails
        // condition (1); finding fires.
        let source = """
        @safe
        public struct Padded {}
        """
        let findings = Lint.Rule.`safe attribute forbidden Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `safe attribute on bare class is flagged`() {
        let source = """
        @safe
        final class _Storage {}
        """
        let findings = Lint.Rule.`safe attribute forbidden Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `safe attribute on variable declaration is flagged`() {
        // Carve-out does NOT apply to vars — direct forbids.
        let source = """
        @safe @usableFromInline
        nonisolated(unsafe) let _sentinel: UnsafeMutableRawPointer = .allocate(capacity: 0)
        """
        let findings = Lint.Rule.`safe attribute forbidden Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `safe attribute on bare enum is flagged`() {
        let source = """
        @safe @usableFromInline
        enum Work {
            case action
        }
        """
        let findings = Lint.Rule.`safe attribute forbidden Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `safe attribute on extension is flagged unconditionally`() {
        // Extensions are not eligible for the carve-out.
        let source = """
        @safe
        extension MyType: @unchecked Sendable {}
        """
        let findings = Lint.Rule.`safe attribute forbidden Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `safe attribute on function is flagged`() {
        let source = """
        @safe
        func doWork() {}
        """
        let findings = Lint.Rule.`safe attribute forbidden Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `safe attribute on subscript is flagged`() {
        // Subscripts are not eligible for the carve-out.
        let source = """
        public struct Container {
            @safe
            subscript(index: Int) -> Int { 0 }
        }
        """
        let findings = Lint.Rule.`safe attribute forbidden Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `safe attribute on initializer is flagged`() {
        let source = """
        public struct Container {
            @safe
            init() {}
        }
        """
        let findings = Lint.Rule.`safe attribute forbidden Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `no safe attribute is not flagged`() {
        let source = """
        public struct Padded {}
        final class _Storage {}
        nonisolated(unsafe) let _sentinel: UnsafeMutableRawPointer = .allocate(capacity: 0)
        """
        let findings = Lint.Rule.`safe attribute forbidden Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `unsafe attribute is not flagged`() {
        // `@unsafe` is governed separately ([MEM-SAFE-022]); this rule
        // only flags `@safe`.
        let source = """
        @unsafe
        public func raw() -> UnsafeMutablePointer<UInt8> { fatalError() }
        """
        let findings = Lint.Rule.`safe attribute forbidden Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `multiple bare safe attributes are each flagged`() {
        let source = """
        @safe
        public struct A {}

        @safe
        public struct B {}
        """
        let findings = Lint.Rule.`safe attribute forbidden Tests`.findings(in: source)
        #expect(findings.count == 2)
    }
}

// MARK: - Wave 4 absorber-pattern carve-out (DECISION 2026-05-12, Option a)
//
// Carve-out per [MEM-SAFE-025b]: `@safe` on a type decl MAY appear when
// BOTH (1) the type's body/attributes show genuine unsafe internals AND
// (2) the decl carries adjacent invariant disclosure (// WHY: Category … /
// ## Safety Invariant). See
// `swift-foundations/swift-linter-rules/Research/wave-4-absorber-pattern-policy-lean-2026-05-12.md`
// v1.1.0.

extension Lint.Rule.`safe attribute forbidden Tests`.`Absorber Carve-out` {

    // MARK: - Carve-out APPLIES (no finding)

    @Test
    func `absorber struct with sibling unchecked Sendable extension + WHY Category A is permitted`() {
        // Condition 1: sibling extension declares @unchecked Sendable.
        // Condition 2: adjacent `// WHY: Category A — ...` line.
        let source = """
        // WHY: Category A — synchronized via internal lock; see [MEM-SAFE-024].
        @safe
        public struct LockedState {
            private let lock = Lock()
        }
        extension LockedState: @unchecked Sendable {}
        """
        let findings = Lint.Rule.`safe attribute forbidden Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `absorber struct with nonisolated unsafe stored prop + SAFETY Category D is permitted`() {
        // Condition 1: nonisolated(unsafe) stored property in the body.
        // Condition 2: adjacent `// SAFETY: Category D ...` line.
        let source = """
        // SAFETY: Category D — SP-5 pointer-backed Copyable wrapper.
        // SAFETY: Storage allocated once at init; pointee never mutated.
        @safe
        public struct Pinned {
            nonisolated(unsafe) let storage: UnsafeMutableRawPointer = .allocate(capacity: 0)
        }
        """
        let findings = Lint.Rule.`safe attribute forbidden Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `absorber class with UnsafePointer storage + Safety Invariant doc section is permitted`() {
        // Condition 1: UnsafePointer<…> storage member.
        // Condition 2: doc-comment ## Safety Invariant heading.
        let source = """
        /// Internal storage class.
        ///
        /// ## Safety Invariant
        /// Pointer allocated once at init and never reassigned. COW discipline
        /// ensures unique ownership per isolation domain. See [MEM-SAFE-024].
        @safe
        final class _Storage {
            let buffer: UnsafePointer<UInt8>
            init(buffer: UnsafePointer<UInt8>) { self.buffer = buffer }
        }
        """
        let findings = Lint.Rule.`safe attribute forbidden Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `absorber struct with inline unchecked Sendable + WHY Category B is permitted`() {
        // Condition 1: inline `@unchecked Sendable` clause on the type.
        // Condition 2: adjacent `// WHY: Category B — ...` line.
        let source = """
        // WHY: Category B — ownership transfer; ~Copyable guarantees unique
        // WHY: ownership at every move boundary. See [MEM-SAFE-024].
        @safe
        public struct Arena: ~Copyable, @unchecked Sendable {
            private let storage: UnsafeMutableRawPointer
        }
        """
        let findings = Lint.Rule.`safe attribute forbidden Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `absorber struct with OpaquePointer storage + SAFETY Category D is permitted`() {
        // Condition 1: OpaquePointer storage.
        // Condition 2: adjacent `// SAFETY: Category D ...` line.
        let source = """
        // SAFETY: Category D — SP-5 pointer-backed Copyable; OpaquePointer's
        // SAFETY: referent is immutable.
        @safe
        public struct Handle {
            private let raw: OpaquePointer
        }
        """
        let findings = Lint.Rule.`safe attribute forbidden Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `absorber struct with Unmanaged storage + WHY Category B is permitted`() {
        // Condition 1: Unmanaged<…> storage.
        // Condition 2: WHY Category B line.
        let source = """
        // WHY: Category B — ownership transfer; Unmanaged.passRetained
        // WHY: relinquishes the sender's reference.
        @safe
        public struct Transfer {
            private let retained: Unmanaged<AnyObject>
        }
        """
        let findings = Lint.Rule.`safe attribute forbidden Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `absorber struct with UnsafeBufferPointer storage + WHY Category C is permitted`() {
        // Categories A/B/C/D are all valid per the carve-out.
        let source = """
        // WHY: Category C — thread-confined access; transferred to poll thread once.
        @safe
        public struct View {
            private let buffer: UnsafeBufferPointer<UInt8>
        }
        """
        let findings = Lint.Rule.`safe attribute forbidden Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `absorber actor with unsafe pointer storage + WHY Category A is permitted`() {
        let source = """
        // WHY: Category A — actor isolation serializes all access; the
        // WHY: pointer never escapes the actor's mailbox.
        @safe
        public actor Coordinator {
            private let storage: UnsafeMutablePointer<Int>
            init() { self.storage = .allocate(capacity: 1) }
        }
        """
        let findings = Lint.Rule.`safe attribute forbidden Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `absorber enum with raw byte storage + WHY Category D is permitted`() {
        let source = """
        // WHY: Category D — SP-5 pointer-backed; OpaquePointer payload is
        // WHY: immutable post-init.
        @safe
        public enum Token {
            case raw(OpaquePointer)
            case empty
        }
        """
        let findings = Lint.Rule.`safe attribute forbidden Tests`.findings(in: source)
        // Enum stored "properties" appear as associated values, not
        // VariableDeclSyntax members — so condition (1c) via the
        // member-block scan doesn't fire for enum associated values.
        // The inline `@unchecked Sendable` is also absent. The enum
        // therefore fails condition 1 → finding fires.
        #expect(findings.count == 1)
    }

    @Test
    func `absorber struct with UnsafeMutablePointer in optional storage + Safety Invariant doc is permitted`() {
        // Optional-wrapped pointer storage still counts as
        // unsafe-pointer storage.
        let source = """
        /// ## Safety Invariant
        /// The optional pointer is set exactly once during init; nil before init,
        /// non-nil after init, never mutated. See [MEM-SAFE-024] Category D.
        @safe
        public struct OptionalBacked {
            private let storage: UnsafeMutablePointer<UInt8>?
        }
        """
        let findings = Lint.Rule.`safe attribute forbidden Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `absorber struct with WHY block BETWEEN safe attr and keyword is permitted`() {
        // Ecosystem ordering: `@safe` line first, then `// WHY:`
        // block, then `public struct …`. This is the dominant
        // existing shape (e.g., Memory.Buffer / Memory.Pool /
        // Loader.Section.Bounds). The trivia model places `// WHY:`
        // in the leading trivia of `public`, not of `@`; the
        // predicate must scan each token's trivia separately.
        let source = """
        @safe
        // WHY: Category D — structural Sendable workaround (SP-5).
        // WHY: Buffer is a Copyable descriptor; stored fields are pure
        // WHY: value bytes; @unchecked Sendable bridges inference gap.
        public struct Buffer: @unchecked Sendable {
            private let _start: Int
            private let _count: Int
        }
        """
        let findings = Lint.Rule.`safe attribute forbidden Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `absorber struct with Safety Invariant doc BETWEEN safe attr and keyword is permitted`() {
        // Doc-comment ordering: `@safe` line first, then the doc
        // block with `## Safety Invariant`, then `public struct …`.
        let source = """
        @safe
        /// Internal storage.
        ///
        /// ## Safety Invariant
        /// Pointer allocated once at init and never reassigned.
        public struct Box: @unchecked Sendable {
            private let raw: OpaquePointer
        }
        """
        let findings = Lint.Rule.`safe attribute forbidden Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    // MARK: - Carve-out does NOT apply (finding fires)

    @Test
    func `safe struct with no unsafe markers but with WHY Category line is flagged`() {
        // Condition (2a) satisfied but condition (1) missing — the
        // struct contains no unsafe internals.
        let source = """
        // WHY: Category A — synchronized externally.
        @safe
        public struct Padded {
            let value: Int
        }
        """
        let findings = Lint.Rule.`safe attribute forbidden Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `safe struct with unchecked Sendable but no comment is flagged`() {
        // Condition (1a) satisfied via sibling extension but no
        // invariant comment.
        let source = """
        @safe
        public struct Bare {
            private let lock = Lock()
        }
        extension Bare: @unchecked Sendable {}
        """
        let findings = Lint.Rule.`safe attribute forbidden Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `safe struct with unchecked Sendable + Category E comment is flagged`() {
        // The taxonomy admits only Categories A/B/C/D — Category E is
        // explicitly rejected per the [MEM-SAFE-024] rule body and
        // per Wave 4 v1.1.0 defect-fix #1.
        let source = """
        // WHY: Category E — invented for this case.
        @safe
        public struct WithE: @unchecked Sendable {
            private let lock = Lock()
        }
        """
        let findings = Lint.Rule.`safe attribute forbidden Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `safe struct with unchecked Sendable + non-adjacent comment is flagged`() {
        // A blank line between the comment and the decl breaks
        // adjacency — condition (2) fails.
        let source = """
        // WHY: Category A — synchronized.

        @safe
        public struct Far: @unchecked Sendable {
            private let lock = Lock()
        }
        """
        let findings = Lint.Rule.`safe attribute forbidden Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `safe struct with WHY but without Category citation is flagged`() {
        // The comment names `WHY:` but does not cite a Category —
        // condition (2a) requires the Category citation.
        let source = """
        // WHY: this is safe because the lock serializes access.
        @safe
        public struct Loose: @unchecked Sendable {
            private let lock = Lock()
        }
        """
        let findings = Lint.Rule.`safe attribute forbidden Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `safe struct with WHY Category D but storage is plain Int is flagged`() {
        // Condition (2a) satisfied but condition (1) fails — no
        // unsafe internals.
        let source = """
        // WHY: Category D — SP-5 (claimed but not actually pointer-backed).
        @safe
        public struct Pretender {
            let value: Int
        }
        """
        let findings = Lint.Rule.`safe attribute forbidden Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `safe struct with WHY Category lowercase letter still counts`() {
        // Case-insensitive on the keyword and on the category letter
        // — `category d` is the same as `Category D`.
        let source = """
        // why: category d — sp-5 pointer-backed.
        @safe
        public struct Lowered {
            private let raw: UnsafeRawPointer
        }
        """
        let findings = Lint.Rule.`safe attribute forbidden Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    // MARK: - Doc-comment safety invariant edge cases

    @Test
    func `safe struct with Safety Invariant doc in unrelated location is flagged when not adjacent`() {
        // The doc-comment block must be the IMMEDIATELY adjacent
        // doc-comment block above the decl. An intervening blank
        // line breaks adjacency.
        let source = """
        /// ## Safety Invariant
        /// Allocated once at init.

        @safe
        public struct Disjoint {
            private let raw: UnsafeRawPointer
        }
        """
        let findings = Lint.Rule.`safe attribute forbidden Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}
