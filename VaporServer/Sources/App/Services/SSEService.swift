import Foundation
import Vapor

actor SSEService {
    private var connections: [UUID: AsyncStream<SSEEvent>.Continuation] = [:]

    enum SSEEvent: Sendable {
        case cardsUpdated
        case cardCreated(UUID)
        case cardArchived(UUID)
        case ping

        var eventName: String {
            switch self {
            case .cardsUpdated: return "cards-updated"
            case .cardCreated: return "card-created"
            case .cardArchived: return "card-archived"
            case .ping: return "ping"
            }
        }

        var data: String {
            switch self {
            case .cardsUpdated:
                return "refresh"
            case .cardCreated(let id):
                return id.uuidString
            case .cardArchived(let id):
                return id.uuidString
            case .ping:
                return "keepalive"
            }
        }

        func toSSEString() -> String {
            "event: \(eventName)\ndata: \(data)\n\n"
        }
    }

    func addConnection() -> (id: UUID, stream: AsyncStream<SSEEvent>) {
        let id = UUID()
        let stream = AsyncStream<SSEEvent> { continuation in
            Task {
                await self.storeConnection(id: id, continuation: continuation)
            }

            continuation.onTermination = { @Sendable _ in
                Task {
                    await self.removeConnection(id: id)
                }
            }
        }
        return (id, stream)
    }

    private func storeConnection(id: UUID, continuation: AsyncStream<SSEEvent>.Continuation) {
        connections[id] = continuation
        print("SSE client connected (total: \(connections.count))")
    }

    func removeConnection(id: UUID) {
        connections.removeValue(forKey: id)
        print("SSE client disconnected (total: \(connections.count))")
    }

    func broadcast(event: SSEEvent) {
        for (_, continuation) in connections {
            continuation.yield(event)
        }
    }

    var connectionCount: Int {
        connections.count
    }
}
