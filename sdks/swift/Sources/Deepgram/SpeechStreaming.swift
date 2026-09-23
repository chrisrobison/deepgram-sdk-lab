import Foundation

public enum SpeechEvent: Sendable {
    case audio(Data)
    case metadata(SpeakV1_SpeakV1Metadata)
    case flushed(SpeakV1_SpeakV1Flushed)
    case cleared(SpeakV1_SpeakV1Cleared)
    case warning(SpeakV1_SpeakV1Warning)
    case unknown(type: String?, payload: JSONValue)
    case malformed(Data)
}

public struct SpeakV1: Sendable {
    let core: RESTClient

    public func connect(model: String = "aura-2-asteria-en", encoding: String = "linear16", sampleRate: Int = 24_000,
                        reconnectPolicy: ReconnectPolicy = .init()) async throws -> RealtimeSpeechStream {
        let query = [URLQueryItem(name: "model", value: model), URLQueryItem(name: "encoding", value: encoding),
                     URLQueryItem(name: "sample_rate", value: String(sampleRate))]
        return try await RealtimeSpeechStream.connect(core: core, query: query, reconnectPolicy: reconnectPolicy)
    }
}

extension SpeakClient {
    public var v1: SpeakV1 { SpeakV1(core: core) }
}

public actor RealtimeSpeechStream {
    public nonisolated let events: AsyncThrowingStream<SpeechEvent, Error>
    public private(set) var state: ConnectionState = .connecting
    private let core: RESTClient
    private let query: [URLQueryItem]
    private let reconnectPolicy: ReconnectPolicy
    private let socketFactory: @Sendable (URLRequest) -> any SocketTransport
    private var continuation: AsyncThrowingStream<SpeechEvent, Error>.Continuation
    private var socket: (any SocketTransport)?
    private var receiveTask: Task<Void, Never>?
    private var sendTail: Task<Void, Error>?
    private var textSent = false
    private var reconnectAttempts = 0

    private init(core: RESTClient, query: [URLQueryItem], reconnectPolicy: ReconnectPolicy,
                 socketFactory: @escaping @Sendable (URLRequest) -> any SocketTransport) {
        self.core = core
        self.query = query
        self.reconnectPolicy = reconnectPolicy
        self.socketFactory = socketFactory
        var receiver: AsyncThrowingStream<SpeechEvent, Error>.Continuation!
        events = AsyncThrowingStream(bufferingPolicy: .bufferingNewest(128)) { receiver = $0 }
        continuation = receiver
    }

    static func connect(core: RESTClient, query: [URLQueryItem], reconnectPolicy: ReconnectPolicy,
                        socketFactory: @escaping @Sendable (URLRequest) -> any SocketTransport = { NativeSocket(request: $0) }) async throws -> RealtimeSpeechStream {
        let stream = RealtimeSpeechStream(core: core, query: query, reconnectPolicy: reconnectPolicy, socketFactory: socketFactory)
        try await stream.open()
        return stream
    }

    private func request() throws -> URLRequest {
        guard !core.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw DeepgramError.invalidConfiguration("API key is empty") }
        guard var components = URLComponents(url: core.baseURL, resolvingAgainstBaseURL: false),
              components.scheme == "https" || (components.scheme == "http" && ["localhost", "127.0.0.1"].contains(components.host ?? "")) else {
            throw DeepgramError.invalidConfiguration("WebSocket base URL must use HTTPS except for localhost")
        }
        components.scheme = components.scheme == "https" ? "wss" : "ws"
        components.path = "/v1/speak"
        components.queryItems = query
        guard let url = components.url else { throw DeepgramError.invalidConfiguration("invalid WebSocket URL") }
        var request = URLRequest(url: url)
        request.setValue("Token \(core.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("deepgram-sdk-lab-swift/\(Deepgram.version)", forHTTPHeaderField: "User-Agent")
        return request
    }

    private func open() async throws {
        let request = try request()
        for attempt in 0...reconnectPolicy.maxAttempts {
            if Task.isCancelled { throw DeepgramError.cancelled }
            let candidate = socketFactory(request)
            do {
                try await candidate.open()
                socket = candidate
                sendTail = nil
                state = .open
                receiveTask = Task { [weak self, candidate] in
                    do {
                        while !Task.isCancelled {
                            let message = try await candidate.receive()
                            guard let self else { candidate.cancel(); return }
                            await self.accept(message)
                        }
                    } catch {
                        guard let self else { candidate.cancel(); return }
                        await self.disconnected(error)
                    }
                }
                return
            } catch {
                candidate.cancel()
                if attempt == reconnectPolicy.maxAttempts { throw DeepgramError.connection(String(describing: error)) }
                state = .reconnecting(attempt + 1)
                try await Task.sleep(for: reconnectPolicy.delay)
            }
        }
    }

    private func accept(_ message: SocketMessage) {
        switch message {
        case .data(let data): emit(.audio(data))
        case .text(let text):
            let data = Data(text.utf8)
            guard let raw = try? JSONDecoder().decode(JSONValue.self, from: data), case .object(let object) = raw else {
                emit(.malformed(data)); return
            }
            let type: String? = if case .string(let value)? = object["type"] { value } else { nil }
            do {
                let decoder = JSONDecoder()
                let event: SpeechEvent = switch type {
                case "Metadata": .metadata(try decoder.decode(SpeakV1_SpeakV1Metadata.self, from: data))
                case "Flushed": .flushed(try decoder.decode(SpeakV1_SpeakV1Flushed.self, from: data))
                case "Cleared": .cleared(try decoder.decode(SpeakV1_SpeakV1Cleared.self, from: data))
                case "Warning": .warning(try decoder.decode(SpeakV1_SpeakV1Warning.self, from: data))
                default: .unknown(type: type, payload: raw)
                }
                emit(event)
            } catch { emit(.malformed(data)) }
        }
    }

    private func emit(_ event: SpeechEvent) {
        if case .dropped = continuation.yield(event) {
            finish(DeepgramError.protocolViolation("speech event buffer overflow"))
        }
    }

    private func disconnected(_ error: Error) async {
        guard state != .closed && state != .closing else { return }
        socket?.cancel()
        if !textSent && reconnectAttempts < reconnectPolicy.maxAttempts {
            reconnectAttempts += 1
            state = .reconnecting(reconnectAttempts)
            do {
                try await Task.sleep(for: reconnectPolicy.delay)
                try await open()
                return
            } catch { finish(DeepgramError.connection(String(describing: error))); return }
        }
        finish(DeepgramError.interrupted("speech stream ended; text was not replayed: \(error)"))
    }

    private func finish(_ error: Error? = nil) {
        guard state != .closed else { return }
        state = .closed
        socket?.cancel()
        receiveTask?.cancel()
        continuation.finish(throwing: error)
    }

    private func send(_ message: SocketMessage) async throws {
        if Task.isCancelled { throw DeepgramError.cancelled }
        guard state == .open, let socket else { throw DeepgramError.closed }
        let previous = sendTail
        let next = Task {
            try await previous?.value
            try await socket.send(message)
        }
        sendTail = next
        try await next.value
    }

    public func speak(_ text: String) async throws {
        guard !text.isEmpty else { throw DeepgramError.invalidConfiguration("speech text is empty") }
        textSent = true
        let payload = try JSONEncoder().encode(["type": "Speak", "text": text])
        try await send(.text(String(decoding: payload, as: UTF8.self)))
    }

    public func flush() async throws { try await send(.text("{\"type\":\"Flush\"}")) }
    public func clear() async throws { try await send(.text("{\"type\":\"Clear\"}")) }

    public func close() async {
        guard state != .closed else { return }
        state = .closing
        try? await sendTail?.value
        try? await socket?.send(.text("{\"type\":\"Close\"}"))
        finish()
    }

    deinit { socket?.cancel() }
}
