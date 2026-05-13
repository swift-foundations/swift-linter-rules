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

internal enum LifecycleTier {
    case completion
    case body
    case other
}

internal func lifecycleTier(of parameter: FunctionParameterSyntax) -> LifecycleTier {
    if parameter.firstName.tokenKind == .wildcard {
        return .body
    }
    let labelText = parameter.firstName.text
    if completionTierLabels.contains(labelText) {
        return .completion
    }
    if bodyTierLabels.contains(labelText) {
        return .body
    }
    return .other
}
