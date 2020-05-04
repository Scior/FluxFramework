# FluxFramework

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

----

- [What's this?](#whats-this)
- [Feature](#feature)
- [Installation](#installation)
- [Usage](#usage)
- [License](#license)

## What's this?

**FluxFramework** is a lightweight flux framework for Swift.  
Inspired by:

- <https://github.com/facebook/flux>
- <https://github.com/vuejs/vuex>
- <https://github.com/ReSwift/ReSwift>

## Feature

- Minimum implementation
- Unidirectional data flow
- No dependencies to other libraries

## Installation

In preparation

## Usage

### Define events, actions and action creator

The operations of converting events(`FluxEvent`) into actions(`FluxAction`) must be written in `FluxActionConverter`.
Operations can be asynchronous.

Events and actions can be defined as `enum`. For instance,

```swift
final class ActionConverter: FluxActionConverter {
    enum Event: FluxEvent {
        case add(Model)
        case removeAll
    }
    enum Action: FluxAction {
        case replaceModels([Model])
    }
    typealias Dependency = Void

    static func convert(event: Event, dependency: Dependency, actionHandler: @escaping (Action) -> Void) {
        switch event {
        case .add(let model):
            // let models = ...
            actionHandler(.replaceModels(models))
        case .removeAll:
            // ...
            actionHandler(.replaceParentComment([]]))
        }
    }
}
```

Typically, the following alias will be useful:

```swift
typealias ActionCreator = FluxActionCreator<ActionConverter>
```

### Define state and store

A state(`FluxState`) has some stored properties.
Every mutation for the property must be done in `handle(action:)`.

If any modifications have been made, the return value for `handle` should be `nil` since it notifies the return value for all subscribiers.

For example,

```swift
struct State: FluxState {
    let identifier = UUID().uuidString
  
    private(set) var models: [Model]

    mutating func handle(action: ActionConverter.Action) -> State? {
        switch action {
        case .replaceModels(let models):
            self.models = models
        }

        return self
    }
}
```

Also, the following alias can be used:

```swift
typealias Store = FluxStore<State>
```

### Subscribe and unsubscribe

To observe modifications of the state, 

```swift
let store = FluxStore<State>
let subscription = store.subscribe { state in
    print(state.models.count)
}
```

An explicit unsubscription can be done as below:

```swift
subsciption.unsubscribe()
```

### Trigger events

To trigger events, just call `fire`:

```swift
let actionCreator = FluxActionCreator<ActionConverter>

actionCreator.fire(.add(Model()))
actionCreator.fire([.add(Model()), .removeAll])
```

### Convert to RxSwift's Observable

`FluxStore` can be converted to RxSwift's `Observable` as follows:

```swift
extension FluxStore: ObservableConvertibleType {
    public func asObservable() -> Observable<State> {
        return Observable.create { [weak self] observer -> Disposable in
            guard let self = self else { return Disposables.create() }

            let subscription = self.subscribe { state in
                observer.on(.next(state))
            }

            return Disposables.create {
                subscription.unsubscribe()
            }
        }
    }
}
```

## License

**FluxFramework** is under MIT License.

Copyright (c) 2019 Suita Fujino
