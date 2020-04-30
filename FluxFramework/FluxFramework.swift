//
//  FluxFramework.swift
//  FluxFramework
//
//  Created by Suita Fujino on 2019/11/10.
//  Copyright © 2019 Suita Fujino. All rights reserved.
//

import Foundation

public protocol FluxAction {}
public protocol FluxEvent {}

public protocol FluxActionConverter {
    associatedtype Action: FluxAction
    associatedtype Dependency
    associatedtype Event: FluxEvent
    static func convert(event: Event, dependency: Dependency, actionHandler: @escaping (Action) -> Void)
}

public final class FluxActionCreator<Converter: FluxActionConverter> {
    private let dependency: Converter.Dependency
    private let dispatcher: FluxDispatcher
    
    private let processingQueue: DispatchQueue
    
    public init(
        dependency: Converter.Dependency,
        dispatcher: FluxDispatcher? = nil,
        processingQueue: DispatchQueue = DispatchQueue.main
    ) {
        self.dependency = dependency
        self.dispatcher = dispatcher ?? FluxSharedDispatcher.shared
        self.processingQueue = processingQueue
    }
    
    public func fire(_ event: Converter.Event, executionQueue: DispatchQueue? = nil) {
        (executionQueue ?? processingQueue).async { [weak self] in
            guard let self = self else { return }
            Converter.convert(event: event, dependency: self.dependency, actionHandler: self.dispatcher.dispatch)
        }
    }
    
    public func fire(_ events: [Converter.Event]) {
        for event in events {
            fire(event)
        }
    }
}

public protocol FluxDispatcher {
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

public protocol FluxState {
    associatedtype Action: FluxAction
    var identifier: FluxDispatcher.Identifier { get }
    
    init()
    
    mutating func handle(action: Action) -> Self?
}

public final class FluxStore<State: FluxState> {
    public typealias Identifier = String
    
    private(set) var state: State
    private let dispatcher: FluxDispatcher
    private var observers: [Identifier: (State) -> Void]
    
    public init(dispatcher: FluxDispatcher? = nil) {
        self.dispatcher = dispatcher ?? FluxSharedDispatcher.shared
        state = .init()
        observers = [:]
        
        self.dispatcher.subscribe(for: state.identifier) { [weak self] action in
            guard let self = self else { return }
            guard let action = action as? State.Action else { return }
            
            if let state = self.state.handle(action: action) {
                self.state = state
                self.observers.values.forEach { $0(state) }
            }
        }
    }
    
    deinit {
        dispatcher.unsubscribe(for: state.identifier)
    }
    
    @discardableResult
    public func subscribe(handler: @escaping (State) -> Void) -> FluxSubscription {
        let identifier = UUID().uuidString
        observers[identifier] = handler
        
        return FluxSubscription(unsubscribeHandler: { [weak self] in
            self?.observers.removeValue(forKey: identifier)
        })
    }
}

public struct FluxSubscription {
    private let unsubscribeHandler: () -> Void
    
    public init(unsubscribeHandler: @escaping () -> Void) {
        self.unsubscribeHandler = unsubscribeHandler
    }
    
    public func unsubscribe() {
        unsubscribeHandler()
    }
}
