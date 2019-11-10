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
    static func convert(event: Event, dependency: Dependency) -> Action
}

final class FluxActionCreator<Converter: FluxActionConverter> {
    enum QueueType {
        case concurrent
        case serial
    }
    
    private let dependency: Converter.Dependency
    private let dispatcher: FluxDispatcher
    
    private let concurrentQueue: DispatchQueue
    private let serialQueue = DispatchQueue(label: "com.private.actioncreator.flux", qos: .userInteractive)
    
    init(
        dependency: Converter.Dependency,
        dispatcher: FluxDispatcher = FluxSharedDispatcher.shared,
        concurrentQueue: DispatchQueue = DispatchQueue.global(qos: .userInteractive)
    ) {
        self.dependency = dependency
        self.dispatcher = dispatcher
        self.concurrentQueue = concurrentQueue
    }
    
    func fire(_ event: Converter.Event, queueType: QueueType = .concurrent) {
        let queue: DispatchQueue = {
            switch queueType {
            case .concurrent:
                return concurrentQueue
            case .serial:
                return serialQueue
            }
        }()
        
        queue.async { [weak self] in
            guard let self = self else { return }
            self.dispatcher.dispatch(action: Converter.convert(event: event, dependency: self.dependency))
        }
    }
    
    func fire(_ events: [Converter.Event], queueType: QueueType = .concurrent) {
        for event in events {
            fire(event, queueType: queueType)
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
    private let processingQueue = DispatchQueue(label: "com.private.dispatcher.flux", qos: .userInteractive)
    
    init() {
        observingStores = [:]
    }
    
    func subscribe(for identifier: Identifier, handler: @escaping (FluxAction) -> Void) {
        processingQueue.sync {
            observingStores[identifier] = handler
        }
    }
    
    func unsubscribe(for identifier: Identifier) {
        processingQueue.sync {
            _ = observingStores.removeValue(forKey: identifier)
        }
    }
    
    func dispatch(action: FluxAction) {
        processingQueue.sync {
            let group = DispatchGroup()
            for store in observingStores.values {
                DispatchQueue.main.async(group: group) {
                    store(action)
                }
            }
            
            group.wait()
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
        
        return FluxSubscription { [weak self] in
            self?.observers.removeValue(forKey: identifier)
        }
    }
}

struct FluxSubscription {
    private let unsubscribeHandler: () -> Void
    
    init(handler: @escaping () -> Void) {
        unsubscribeHandler = handler
    }
    
    func unsubscribe() {
        unsubscribeHandler()
    }
}
