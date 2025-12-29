import Vapor
import Leaf

func configure(_ app: Application) async throws {
    // Serve on all network interfaces for LAN access
    app.http.server.configuration.hostname = "0.0.0.0"
    app.http.server.configuration.port = 8080

    // Configure Leaf templating
    app.views.use(.leaf)

    // Serve static files from Public directory
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    // Initialize services
    let syncPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Documents/WordCard/sync.json")

    // Ensure directory exists
    let syncDir = syncPath.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: syncDir, withIntermediateDirectories: true)

    let cardStore = CardStore(syncFilePath: syncPath)
    app.cardStore = cardStore

    let sseService = SSEService()
    app.sseService = sseService

    let fileWatcher = FileWatcherService(
        watchPath: syncPath,
        cardStore: cardStore,
        sseService: sseService
    )
    app.fileWatcher = fileWatcher

    // Start file watcher
    try await fileWatcher.start()

    // Load initial data
    try await cardStore.loadFromFile()

    // Print server info
    printServerInfo()

    // Register routes
    try routes(app)
}

private func printServerInfo() {
    print("""

    ╔══════════════════════════════════════════════════════╗
    ║           WordCard LAN Server Started                ║
    ╠══════════════════════════════════════════════════════╣
    """)

    // Get local IP addresses
    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifaddr) == 0 else {
        print("║  http://localhost:8080                               ║")
        print("╚══════════════════════════════════════════════════════╝\n")
        return
    }
    defer { freeifaddrs(ifaddr) }

    var addresses: [String] = []
    var ptr = ifaddr
    while ptr != nil {
        defer { ptr = ptr?.pointee.ifa_next }
        guard let interface = ptr else { continue }

        let addrFamily = interface.pointee.ifa_addr.pointee.sa_family
        if addrFamily == UInt8(AF_INET) {
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(
                interface.pointee.ifa_addr,
                socklen_t(interface.pointee.ifa_addr.pointee.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            let address = String(cString: hostname)
            if address != "127.0.0.1" && !address.starts(with: "169.254") {
                addresses.append(address)
            }
        }
    }

    print("║  Access from any device on your network:             ║")
    for addr in addresses {
        let url = "http://\(addr):8080"
        let padding = String(repeating: " ", count: max(0, 52 - url.count))
        print("║  \(url)\(padding)║")
    }
    print("║                                                      ║")
    print("║  Local: http://localhost:8080                        ║")
    print("╚══════════════════════════════════════════════════════╝\n")
}

// MARK: - Application Storage Keys

struct CardStoreKey: StorageKey {
    typealias Value = CardStore
}

struct SSEServiceKey: StorageKey {
    typealias Value = SSEService
}

struct FileWatcherKey: StorageKey {
    typealias Value = FileWatcherService
}

extension Application {
    var cardStore: CardStore {
        get { storage[CardStoreKey.self]! }
        set { storage[CardStoreKey.self] = newValue }
    }

    var sseService: SSEService {
        get { storage[SSEServiceKey.self]! }
        set { storage[SSEServiceKey.self] = newValue }
    }

    var fileWatcher: FileWatcherService {
        get { storage[FileWatcherKey.self]! }
        set { storage[FileWatcherKey.self] = newValue }
    }
}
