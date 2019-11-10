//
//  FluxFramework.swift
//  FluxFramework
//
//  Created by Suita Fujino on 2019/11/10.
//  Copyright © 2019 Suita Fujino. All rights reserved.
//

import Foundation

protocol FluxAction {}
protocol FluxEvent {}

protocol FluxActionConverter {
    associatedtype Action: FluxAction
    associatedtype Dependency
    associatedtype Event: FluxEvent
    static func convert(event: Event, dependency: Dependency, actionHandler: @escaping (Action) -> Void)
}

final class FluxActionCreator<Converter: FluxActionConverter> {
    private let dependency: Converter.Dependency
    private let dispatcher: FluxDispatcher
    
    private let processingQueue: DispatchQueue
    
    init(
        dependency: Converter.Dependency,
        dispatcher: FluxDispatcher = FluxSharedDispatcher.shared,
        processingQueue: DispatchQueue = DispatchQueue.global(qos: .userInteractive)
    ) {
        self.dependency = dependency
        self.dispatcher = dispatcher
        self.processingQueue = processingQueue
    }
    
    func fire(_ event: Converter.Event) {
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            Converter.convert(event: event, dependency: self.dependency, actionHandler: self.dispatcher.dispatch)
        }
    }
    
    func fire(_ events: [Converter.Event]) {
        for event in events {
            fire(event)
        }
    }
}

protocol FluxDispatcher {
    typealias Identifier = String
    func subscribe(for identifier: Identifier, handler: @escaping (FluxAction) -> Void)
    func unsubscribe(for identifier: Identifier)
    func dispatch(action: FluxAction)
}

fileprivate final class FluxSharedDispatcher: FluxDispatcher {
    static let shared = FluxSharedDispatcher()
    
    private var observingStores: [Identifier: (FluxAction) -> Void]
    private let lock: NSRecursiveLock
    
    init() {
        observingStores = [:]
        lock = NSRecursiveLock()
    }
    
    func subscribe(for identifier: Identifier, handler: @escaping (FluxAction) -> Void) {
        observingStores[identifier] = handler
    }
    
    func unsubscribe(for identifier: Identifier) {
        _ = observingStores.removeValue(forKey: identifier)
    }
    
    func dispatch(action: FluxAction) {
        defer { lock.unlock() }
        lock.lock()
        
        for store in observingStores.values {
            store(action)
        }
    }
}

protocol FluxState {
    associatedtype Action: FluxAction
    static var identifier: FluxDispatcher.Identifier { get }
    
    init()
    
    mutating func handle(action: Action) -> Self?
}

final class FluxStore<State: FluxState> {
    typealias Identifier = String
    
    private(set) var state: State
    private let dispatcher: FluxDispatcher
    private var observers: [Identifier: (State) -> Void]
    
    init(dispatcher: FluxDispatcher = FluxSharedDispatcher.shared) {
        self.dispatcher = dispatcher
        state = .init()
        observers = [:]
        
        dispatcher.subscribe(for: State.identifier) { [weak self] action in
            guard let self = self else { return }
            guard let action = action as? State.Action else { return }
            
            if let state = self.state.handle(action: action) {
                for observer in self.observers.values {
                    observer(state)
                }
            }
        }
    }
    
    deinit {
        dispatcher.unsubscribe(for: State.identifier)
    }
    
    @discardableResult
    func subscribe(handler: @escaping (State) -> Void) -> FluxSubscription {
        let identifier = UUID().uuidString
        observers[identifier] = handler
        
        return FluxSubscription(unsubscribeHandler: { [weak self] in
            self?.observers.removeValue(forKey: identifier)
        })
    }
}

struct FluxSubscription {
    private let unsubscribeHandler: () -> Void
    
    init(unsubscribeHandler: @escaping () -> Void) {
        self.unsubscribeHandler = unsubscribeHandler
    }
    
    func unsubscribe() {
        unsubscribeHandler()
    }
}
