/// Represents a generic application event.
enum AppEvent {
    case userLoggedIn(userID: String)
    case userLoggedOut
    case dataRefreshed
}

/// Example configuration model.
struct APIConfig {
    let baseURL: URL
    static let `default` = APIConfig(baseURL: URL(string: "https://api.example.com")!)
}

/// A network service that depends on APIConfig.
final class NetworkService {
    private let config: APIConfig
    
    /// Initializes with a given configuration.
    init(configuration: APIConfig) {
        self.config = configuration
    }
    
    /// Performs a dummy request.
    func request(endpoint: String, completion: @escaping (Result<Data, Error>) -> Void) {
        let url = config.baseURL.appendingPathComponent(endpoint)
        /// ... perform network call ...
        completion(.success(Data()))
    }
}

/// A thread-safe singleton that manages app-wide config, events, and services.
final class AppManager {
    
    // MARK: - Singleton Instance
    
    /// The shared, lazily-initialized instance.
    static let shared = AppManager()
    
    /// Private initializer prevents external instantiation.
    private init() {
        /// Optional: load saved config from disk
    }
    
    // MARK: - Thread-safe Configuration Storage
    
    /// Internal storage for config values.
    private var configStore: [String: Any] = [:]
    
    /// NSLock to protect `configStore`.
    private let configLock = NSLock()
    
    /// Sets a configuration value for a given key.
    ///
    /// - Parameters:
    ///   - value: The value to store.
    ///   - key:   The identifier for this config.
    func setConfig(value: Any, forKey key: String) {
        configLock.lock()
        defer { configLock.unlock() }
        configStore[key] = value
    }
    
    /// Retrieves a configuration value.
    ///
    /// - Parameter key: The config identifier.
    /// - Returns: The stored value or `nil`.
    func configValue(forKey key: String) -> Any? {
        configLock.lock()
        defer { configLock.unlock() }
        return configStore[key]
    }
    
    // MARK: - Thread-safe Event Bus
    
    /// Typealias for event handler closures.
    typealias EventHandler = (AppEvent) -> Void
    
    /// Subscriber storage keyed by UUID tokens.
    private var subscribers: [UUID: EventHandler] = [:]
    
    /// A concurrent queue: allows multiple concurrent reads, barrier on writes.
    private let subscriberQueue = DispatchQueue(label: "com.yourapp.AppManager.subscriberQueue",
                                                attributes: .concurrent)
    
    /// Subscribes to events; returns a token for later unsubscription.
    ///
    /// - Parameter handler: Closure invoked on each published event.
    /// - Returns: A UUID token to remove this subscription.
    func subscribe(_ handler: @escaping EventHandler) -> UUID {
        let token = UUID()
        subscriberQueue.async(flags: .barrier) {
            self.subscribers[token] = handler
        }
        return token
    }
    
    /// Unsubscribes a previously registered handler.
    ///
    /// - Parameter token: The UUID returned by `subscribe`.
    func unsubscribe(_ token: UUID) {
        subscriberQueue.async(flags: .barrier) {
            self.subscribers.removeValue(forKey: token)
        }
    }
    
    /// Publishes an event to all current subscribers.
    ///
    /// - Parameter event: The `AppEvent` to broadcast.
    func publish(event: AppEvent) {
        /// Sync read to get a snapshot of subscribers
        let handlers = subscriberQueue.sync { Array(self.subscribers.values) }
        /// Dispatch each handler asynchronously
        for handler in handlers {
            DispatchQueue.global().async {
                handler(event)
            }
        }
    }
    
    // MARK: - Lazy-initialized Dependent Service
    
    /// A network service that is initialized only when first accessed.
    private lazy var networkService: NetworkService = {
        /// Attempt to read a custom APIConfig, fall back to default
        let config = configValue(forKey: "apiConfig") as? APIConfig ?? .default
        return NetworkService(configuration: config)
    }()
    
    /// Exposes a simple API for making network requests.
    ///
    /// - Parameters:
    ///   - endpoint: API endpoint path.
    ///   - completion: Closure returning the result.
    func performRequest(to endpoint: String,
                        completion: @escaping (Result<Data, Error>) -> Void) {
        networkService.request(endpoint: endpoint, completion: completion)
    }
}
