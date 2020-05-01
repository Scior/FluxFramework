//
//  FluxFramework.swift
//  FluxFramework
//
//  Created by Suita Fujino on 2019/11/10.
//  Copyright © 2019 Suita Fujino. All rights reserved.
//

import Foundation

/// Represents an action to dispatch, which is converted from an event(`FluxEvent`).
public protocol FluxAction {}
/// Represents an event to trigger an action(`FluxAction`).
public protocol FluxEvent {}

/// Represents a converter which processes events(`FluxEvent`) into actions(`FluxAction`)
/// after several asynchronous operations.
public protocol FluxActionConverter {
    associatedtype Action: FluxAction
    associatedtype Dependency
    associatedtype Event: FluxEvent
    
    /// Processes events(`FluxEvent`) into actions(`FluxAction`) passing some asynchronous operations.
    /// (e.g. API calls, DB accesses)
    /// - Parameters:
    ///   - event: The event processed into an action.
    ///   - dependency: The classes used to process given events with asynchronous operations.
    ///   - actionHandler: The handler consumes actions, that is used by the dispatcher(`FluxDispatcher`).
    static func convert(event: Event, dependency: Dependency, actionHandler: @escaping (Action) -> Void)
}

/// An action creator which wraps a converter and supports interfaces to ocuur events.
public final class FluxActionCreator<Converter: FluxActionConverter> {
    private let dependency: Converter.Dependency
    private let dispatcher: FluxDispatcher
    
    private let processingQueue: DispatchQueue
    
    ///
    /// - Parameters:
    ///   - dependency: The classes used in the action converter(`FluxActionConverter`) to process events into actions.
    ///   - dispatcher: The dispatcher used to deliver actions from the action creator to the store.
    ///    The default dispatcher is the private one(`FluxSharedDispatcher`).
    ///   - processingQueue: The dispatch queue to process conversions. The default value is `DispatchQueue.main`.
    public init(
        dependency: Converter.Dependency,
        dispatcher: FluxDispatcher? = nil,
        processingQueue: DispatchQueue = DispatchQueue.main
    ) {
        self.dependency = dependency
        self.dispatcher = dispatcher ?? FluxSharedDispatcher.shared
        self.processingQueue = processingQueue
    }
    
    /// Triggers an event to dispatch an action.
    /// - Parameters:
    ///   - event: The event to trigger.
    ///   - executionQueue: The dispatch queue to process conversions. The default queue is that was set in initializer.
    public func fire(_ event: Converter.Event, executionQueue: DispatchQueue? = nil) {
        (executionQueue ?? processingQueue).async { [weak self] in
            guard let self = self else { return }
            Converter.convert(event: event, dependency: self.dependency, actionHandler: self.dispatcher.dispatch)
        }
    }
    
    /// Triggers events to dispatch actions.
    /// - Parameter events: Events to trigger.
    public func fire(_ events: [Converter.Event]) {
        for event in events {
            fire(event)
        }
    }
}

/// Represents a dispatcher which delivers actions from action creators(`FluxActionCreator`) to stores(`FluxStore`).
public protocol FluxDispatcher {
    typealias Identifier = String
    
    /// Begins the subscription of actions with defining the behaviors when the actions are dispatched.
    /// - Parameters:
    ///   - identifier: The subscription identifier.
    ///   - handler: The handler executed when the actions are dispatched.
    func subscribe(for identifier: Identifier, handler: @escaping (FluxAction) -> Void)
    
    /// Ends the subscription with the corresponding subscription identifier.
    /// - Parameter identifier: The supscription identifier.
    func unsubscribe(for identifier: Identifier)
    
    /// Delivers the action to stores.
    /// - Parameter action: The action.
    func dispatch(action: FluxAction)
}

/// The private shared dispatcher used as the default one.
/// To prevent dispatcher functions from being called directly, it is declared as a `fileprivate` class.
fileprivate final class FluxSharedDispatcher: FluxDispatcher {
    static let shared = FluxSharedDispatcher()
    
    private var observingStores: [Identifier: (FluxAction) -> Void]
    private let lock: NSRecursiveLock
    
    private init() {
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

/// Represents state that has some stored properites.
public protocol FluxState {
    associatedtype Action: FluxAction
    var identifier: FluxDispatcher.Identifier { get }
    
    init()
    
    /// Changes properties with the given action.
    /// - Parameter action: The action.
    /// - Returns: Modified State. If any changes have been made, the return value should be `nil`.
    mutating func handle(action: Action) -> Self?
}

/// A store wrapping a state(`FluxState`) and providing a `subscribe` method.
public final class FluxStore<State: FluxState> {
    public typealias Identifier = String
    
    private(set) var state: State
    private let dispatcher: FluxDispatcher
    private var observers: [Identifier: (State) -> Void]
    
    /// If you do not want to use the shared dispatcher, give some customized dispatcher.
    /// - Parameter dispatcher: The customized dispatcher.
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
    
    /// Makes a subscription which observes state modifications.
    /// - Parameter handler: The handler invoked when the corresponding state is changed.
    @discardableResult
    public func subscribe(handler: @escaping (State) -> Void) -> FluxSubscription {
        let identifier = UUID().uuidString
        observers[identifier] = handler
        
        return FluxSubscription(unsubscribeHandler: { [weak self] in
            self?.observers.removeValue(forKey: identifier)
        })
    }
}

/// A struct represents subscription and provide an `unsubscribe` method.
public struct FluxSubscription {
    private let unsubscribeHandler: () -> Void
    
    public init(unsubscribeHandler: @escaping () -> Void) {
        self.unsubscribeHandler = unsubscribeHandler
    }
    
    public func unsubscribe() {
        unsubscribeHandler()
    }
}
