//
//  Action.swift
//  FluxFrameworkTests
//
//  Created by Suita Fujino on 2019/11/10.
//  Copyright © 2019 Suita Fujino. All rights reserved.
//

import Foundation
@testable import FluxFramework

enum TestEvent: FluxEvent {
    case delayed(Int, time: TimeInterval)
    case immediate(Int)
}

enum TestAction: FluxAction, Equatable {
    case delayed(Int)
    case immediate(Int)
}

struct TestActionConverter: FluxActionConverter {
    typealias Dependency = Void
    
    static func convert(event: TestEvent, dependency: Dependency, actionHandler: @escaping (TestAction) -> Void) {
        switch event {
        case .delayed(let number, let time):
            DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + time) {
                actionHandler(.delayed(number))
            }
        case .immediate(let number):
            actionHandler(.immediate(number))
        }
    }
}
