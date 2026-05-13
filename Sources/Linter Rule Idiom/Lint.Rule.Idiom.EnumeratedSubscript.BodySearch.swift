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

internal import SwiftSyntax

internal final class IdiomEnumeratedSubscriptBodySearch: SyntaxVisitor {
    let indexName: Swift.String
    let receiverText: Swift.String
    var hits: [AbsolutePosition] = []

    init(indexName: Swift.String, receiverText: Swift.String) {
        self.indexName = indexName
        self.receiverText = receiverText
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: SubscriptCallExprSyntax) -> SyntaxVisitorContinueKind {
        let receiverDescription = idiomTrimmed(node.calledExpression.description)
        guard receiverDescription == receiverText else { return .visitChildren }
        guard let firstArgument = node.arguments.first else { return .visitChildren }
        if let reference = firstArgument.expression.as(DeclReferenceExprSyntax.self),
           reference.baseName.text == indexName
        {
            hits.append(node.calledExpression.endPositionBeforeTrailingTrivia)
        }
        return .visitChildren
    }
}
