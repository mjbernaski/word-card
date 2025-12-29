import Vapor

func routes(_ app: Application) throws {
    // Web UI
    app.get { req async throws -> View in
        let cards = await req.application.cardStore.getAllCards()
        return try await req.view.render("index", IndexContext(
            cards: cards,
            categories: CardCategory.allCases.map { $0.rawValue }
        ))
    }

    // API Routes
    let api = app.grouped("api")

    // List all cards (JSON)
    api.get("cards") { req async -> [CardDTO] in
        await req.application.cardStore.getAllCards()
    }

    // Get single card
    api.get("cards", ":id") { req async throws -> CardDTO in
        guard let idString = req.parameters.get("id"),
              let id = UUID(uuidString: idString) else {
            throw Abort(.badRequest, reason: "Invalid card ID")
        }
        guard let card = await req.application.cardStore.getCard(id: id) else {
            throw Abort(.notFound, reason: "Card not found")
        }
        return card
    }

    // Create card
    api.post("cards") { req async throws -> CardDTO in
        let createRequest = try req.content.decode(CreateCardRequest.self)
        let card = CardDTO.create(
            text: createRequest.text,
            category: createRequest.category ?? "idea"
        )
        let created = try await req.application.cardStore.createCard(card)
        await req.application.sseService.broadcast(event: .cardCreated(created.id))
        return created
    }

    // Archive card (soft delete)
    api.delete("cards", ":id") { req async throws -> HTTPStatus in
        guard let idString = req.parameters.get("id"),
              let id = UUID(uuidString: idString) else {
            throw Abort(.badRequest, reason: "Invalid card ID")
        }
        guard let _ = try await req.application.cardStore.archiveCard(id: id) else {
            throw Abort(.notFound, reason: "Card not found")
        }
        await req.application.sseService.broadcast(event: .cardArchived(id))
        return .ok
    }

    // HTMX Routes (return HTML partials)
    let htmx = app.grouped("htmx")

    // Create card and return card partial
    htmx.post("cards") { req async throws -> View in
        let createRequest = try req.content.decode(CreateCardRequest.self)
        let card = CardDTO.create(
            text: createRequest.text,
            category: createRequest.category ?? "idea"
        )
        let created = try await req.application.cardStore.createCard(card)
        await req.application.sseService.broadcast(event: .cardCreated(created.id))
        return try await req.view.render("_card", CardContext(card: created))
    }

    // Archive card and return empty (for removal from DOM)
    htmx.delete("cards", ":id") { req async throws -> Response in
        guard let idString = req.parameters.get("id"),
              let id = UUID(uuidString: idString) else {
            throw Abort(.badRequest, reason: "Invalid card ID")
        }
        guard let _ = try await req.application.cardStore.archiveCard(id: id) else {
            throw Abort(.notFound, reason: "Card not found")
        }
        await req.application.sseService.broadcast(event: .cardArchived(id))
        return Response(status: .ok, body: .empty)
    }

    // Get updated card list (for SSE refresh)
    htmx.get("cards") { req async throws -> View in
        let cards = await req.application.cardStore.getAllCards()
        return try await req.view.render("_cards", CardsContext(cards: cards))
    }

    // SSE endpoint for real-time updates
    app.get("events") { req async throws -> Response in
        let (connectionId, stream) = await req.application.sseService.addConnection()

        let response = Response(status: .ok)
        response.headers.contentType = HTTPMediaType(type: "text", subType: "event-stream")
        response.headers.add(name: "Cache-Control", value: "no-cache")
        response.headers.add(name: "Connection", value: "keep-alive")

        response.body = .init(asyncStream: { writer in
            // Send initial connection message
            try await writer.write(.buffer(.init(string: "event: connected\ndata: ok\n\n")))

            for await event in stream {
                let data = ByteBuffer(string: event.toSSEString())
                try await writer.write(.buffer(data))
            }

            await req.application.sseService.removeConnection(id: connectionId)
            try await writer.write(.end)
        })

        return response
    }
}

// MARK: - View Contexts

struct IndexContext: Encodable {
    let cards: [CardDTO]
    let categories: [String]
}

struct CardContext: Encodable {
    let card: CardDTO
}

struct CardsContext: Encodable {
    let cards: [CardDTO]
}
