# Thread Safe Singleton

A robust, thread-safe singleton in Swift that centralizes:

- **Configuration Storage**  
  Store and retrieve key/value settings safely across threads using `NSLock`.  
- **Event Bus**  
  Publish and subscribe to application-wide events with a concurrent queue + barrier writes.  
- **Lazy-Initialized Services**  
  Initialize heavyweight services (e.g. networking) only when needed, with fallback to default configuration.

---

## Features

1. **Singleton Guarantee**  
   - `static let shared` ensures a single, lazily-initialized instance.  
   - `private init()` prevents external instantiation.

2. **Thread-Safe Configuration**  
   - Config values held in a `[String: Any]` store.  
   - Protected by `NSLock` for safe, atomic reads and writes.

3. **Event Bus (Publish/Subscribe)**  
   - Subscribers register closures and receive an opaque `UUID` token.  
   - Backed by a `.concurrent` `DispatchQueue` with `.barrier` for writes.  
   - Publishing creates a snapshot of handlers and dispatches them asynchronously.

4. **Lazy Service Initialization**  
   - Example network service (`NetworkService`) is created on first use.  
   - Reads optional custom `APIConfig` from the config store or falls back to `APIConfig.default`.

---

## Usage

```swift
/// 1. Set a custom API endpoint
guard let url = URL(string: "https://api.custom.com") else {
  return
}
AppManager.shared.setConfig(value: APIConfig(baseURL: url), 
                            forKey: "apiConfig")

/// 2. Subscribe to events
let token = AppManager.shared.subscribe { event in
    switch event {
    case .userLoggedIn(let id):
        print("Logged in:", id)
    case .dataRefreshed:
        print("Data was refreshed")
    default:
        break
    }
}

/// 3. Publish an event
AppManager.shared.publish(event: .userLoggedIn(userID: "42"))

/// 4. Perform a network request
AppManager.shared.performRequest(to: "users/42") { result in
    switch result {
    case .success(let data):
        /// handle data
    case .failure(let error):
        /// handle error
    }
}

/// 5. Unsubscribe when no longer needed
AppManager.shared.unsubscribe(token)
