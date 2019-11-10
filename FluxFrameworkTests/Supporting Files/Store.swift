//
//  Store.swift
//  FluxFrameworkTests
//
//  Created by Suita Fujino on 2019/11/10.
//  Copyright © 2019 Suita Fujino. All rights reserved.
//

import Foundation
@testable import FluxFramework

struct TestState: FluxState {
    typealias Action = TestAction
    
    static let identifier = "test_state"
    private(set) var actions: [Action]

    init() {
        actions = []
    }

    mutating func handle(action: Action) -> TestState? {
        actions.append(action)

        return self
    }
}
