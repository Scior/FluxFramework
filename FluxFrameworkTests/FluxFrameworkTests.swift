//
//  FluxFrameworkTests.swift
//  FluxFrameworkTests
//
//  Created by Suita Fujino on 2019/11/10.
//  Copyright © 2019 Suita Fujino. All rights reserved.
//

import XCTest
@testable import FluxFramework

class FluxFrameworkTests: XCTestCase {
    var actionCreator: FluxActionCreator<TestActionConverter>!
    var store: FluxStore<TestState>!
    
    override func setUp() {
        super.setUp()
        
        actionCreator = FluxActionCreator<TestActionConverter>(dependency: ())
        store = FluxStore<TestState>()
    }
    
    // MARK: - Subscription

    func testSubscriptionWithASingleEvent() {
        let expectation = XCTestExpectation(description: "Registered closure is triggered.")
        let subscription = store.subscribe { state in
            expectation.fulfill()
        }
        defer { subscription.unsubscribe() }
        
        actionCreator.fire(.immediate(0))
        
        wait(for: [expectation], timeout: 0.2)
    }
    
    func testSubscriptionWithThreeEvents() {
        let expectation = XCTestExpectation(description: "Registered closure is triggered 3 times.")
        var states: [TestState] = []
        
        let subscription = store.subscribe { state in
            states.append(state)
            
            if states.count == 3 {
                expectation.fulfill()
            }
        }
        defer { subscription.unsubscribe() }
        
        actionCreator.fire([.immediate(0), .immediate(1), .immediate(2)])
        
        wait(for: [expectation], timeout: 0.2)
    }
    
    func testMultipleSubscription() {
        let expectation = XCTestExpectation(description: "Registered closure is triggered 3 times.")
        let expectation2 = XCTestExpectation(description: "Registered closure is triggered 3 times.")
        var states: [TestState] = []
        var states2: [TestState] = []
        
        let subscription = store.subscribe { state in
            states.append(state)
            
            if states.count == 3 {
                expectation.fulfill()
            }
        }
        defer { subscription.unsubscribe() }
        
        let subscription2 = store.subscribe { state in
            states2.append(state)
            
            if states2.count == 3 {
                expectation2.fulfill()
            }
        }
        defer { subscription2.unsubscribe() }
        
        actionCreator.fire([.immediate(0), .immediate(1), .immediate(2)])
        
        wait(for: [expectation, expectation2], timeout: 0.2)
    }
    
    // MARK: - Unsubscription
    
    func testUnsubscription() {
        let expectation = XCTestExpectation(description: "Unsubscripted")
        var states: [TestState] = []
        
        var subscription: FluxSubscription?
        let unsubscriptHandler = {
            subscription?.unsubscribe()
            expectation.fulfill()
        }
        subscription = store.subscribe { state in
            states.append(state)
            
            if states.count == 1 {
                unsubscriptHandler()
            }
        }
        defer { subscription?.unsubscribe() }
        
        actionCreator.fire([.immediate(0), .immediate(1), .immediate(2)])
        
        wait(for: [expectation], timeout: 0.2)
        XCTAssertEqual(states.count, 1)
    }
    
    // MARK: - Method Order
    
    func testMethodOrderWithThreeDelayedAsyncEvents() {
        let expectation = XCTestExpectation(description: "Registered closure is triggered 3 times.")
        var states: [TestState] = []
        
        let subscription = store.subscribe { state in
            states.append(state)
            
            if states.count == 3 {
                expectation.fulfill()
            }
        }
        defer { subscription.unsubscribe() }
        
        actionCreator.fire([.delayed(0, time: 0.2), .delayed(1, time: 0.1), .delayed(2, time: 0.3)])
        
        wait(for: [expectation], timeout: 0.5)
        
        let expected: [[TestAction]] = [
            [.delayed(1)],
            [.delayed(1), .delayed(0)],
            [.delayed(1), .delayed(0), .delayed(2)]
        ]
        XCTAssertEqual(states.map { $0.actions }, expected)
    }
    
    func testMethodOrderWithMultitypeEvents() {
        let expectation = XCTestExpectation(description: "Registered closure is triggered 3 times.")
        var states: [TestState] = []
        
        let subscription = store.subscribe { state in
            states.append(state)
            
            if states.count == 4 {
                expectation.fulfill()
            }
        }
        defer { subscription.unsubscribe() }
        
        actionCreator.fire([.delayed(0, time: 0.1), .delayed(1, time: 0.05), .immediate(2)])
        actionCreator.fire(.immediate(3))
        
        wait(for: [expectation], timeout: 0.5)
        
        let expected: [[TestAction]] = [
            [.immediate(2)],
            [.immediate(2), .immediate(3)],
            [.immediate(2), .immediate(3), .delayed(1)],
            [.immediate(2), .immediate(3), .delayed(1), .delayed(0)]
        ]
        XCTAssertEqual(states.map { $0.actions }, expected)
    }
}
