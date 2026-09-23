import Foundation

public struct FluxModel: RawRepresentable, Sendable, Hashable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let fluxGeneralEn = FluxModel(rawValue: "flux-general-en")
    public static let fluxGeneralMulti = FluxModel(rawValue: "flux-general-multi")
}

public struct ReconnectPolicy: Sendable {
    public let maxAttempts: Int
    public let delay: Duration
    /// Reconnect is attempted only before audio is sent; sent audio cannot be replayed safely.
    public init(maxAttempts: Int = 0, delay: Duration = .seconds(1)) {
        self.maxAttempts = max(0, maxAttempts)
        self.delay = delay
    }
}

public enum ConnectionState: Sendable, Equatable {
    case connecting, open, reconnecting(Int), closing, closed
}

public enum ListenEvent: Sendable {
    case v1Results(ListenV1_ListenV1Results)
    case v1Metadata(ListenV1_ListenV1Metadata)
    case v1UtteranceEnd(ListenV1_ListenV1UtteranceEnd)
    case v1SpeechStarted(ListenV1_ListenV1SpeechStarted)
    case connected(ListenV2_ListenV2Connected)
    case turnInfo(ListenV2_ListenV2TurnInfo)
    case configureSuccess(ListenV2_ListenV2ConfigureSuccess)
    case configureFailure(ListenV2_ListenV2ConfigureFailure)
    case fatalError(ListenV2_ListenV2FatalError)
    case unknown(type: String?, payload: JSONValue)
    case malformed(Data)
}

public struct ListenV1: Sendable {
    let core: RESTClient

    public func connect(
        model: String = "nova-3", encoding: String? = nil, sampleRate: Int? = nil,
        interimResults: Bool = true, reconnectPolicy: ReconnectPolicy = .init()
    ) async throws -> RealtimeListenStream {
        var query = [URLQueryItem(name: "model", value: model), URLQueryItem(name: "interim_results", value: String(interimResults))]
        if let encoding { query.append(.init(name: "encoding", value: encoding)) }
        if let sampleRate { query.append(.init(name: "sample_rate", value: String(sampleRate))) }
        return try await RealtimeListenStream.connect(core: core, path: "/v1/listen", query: query, reconnectPolicy: reconnectPolicy)
    }
}

public struct ListenV2: Sendable {
    let core: RESTClient

    public func connect(
        model: FluxModel, encoding: String? = nil, sampleRate: Int? = nil,
        reconnectPolicy: ReconnectPolicy = .init()
    ) async throws -> RealtimeListenStream {
        guard (encoding == nil) == (sampleRate == nil) else {
            throw DeepgramError.invalidConfiguration("raw audio requires both encoding and sampleRate")
        }
        var query = [URLQueryItem(name: "model", value: model.rawValue)]
        if let encoding { query.append(.init(name: "encoding", value: encoding)) }
        if let sampleRate { query.append(.init(name: "sample_rate", value: String(sampleRate))) }
        return try await RealtimeListenStream.connect(core: core, path: "/v2/listen", query: query, reconnectPolicy: reconnectPolicy)
    }
}

extension ListenClient {
    public var v1: ListenV1 { ListenV1(core: core) }
    public var v2: ListenV2 { ListenV2(core: core) }
}

public actor RealtimeListenStream {
    public nonisolated let events: AsyncThrowingStream<ListenEvent, Error>
    public private(set) var state: ConnectionState = .connecting
    private let core: RESTClient
    private let path: String
    private let query: [URLQueryItem]
    private let reconnectPolicy: ReconnectPolicy
    private let socketFactory: @Sendable (URLRequest) -> any SocketTransport
    private var continuation: AsyncThrowingStream<ListenEvent, Error>.Continuation
    private var socket: (any SocketTransport)?
    private var receiveTask: Task<Void, Never>?
    private var sendTail: Task<Void, Error>?
    private var audioBytesSent = 0
    private var reconnectAttempts = 0

    private init(core: RESTClient, path: String, query: [URLQueryItem], reconnectPolicy: ReconnectPolicy,
                 socketFactory: @escaping @Sendable (URLRequest) -> any SocketTransport) {
        self.core = core
        self.path = path
        self.query = query
        self.reconnectPolicy = reconnectPolicy
        self.socketFactory = socketFactory
        var receiver: AsyncThrowingStream<ListenEvent, Error>.Continuation!
        self.events = AsyncThrowingStream(bufferingPolicy: .bufferingNewest(128)) { receiver = $0 }
        self.continuation = receiver
    }

    static func connect(core: RESTClient, path: String, query: [URLQueryItem], reconnectPolicy: ReconnectPolicy,
                        socketFactory: @escaping @Sendable (URLRequest) -> any SocketTransport = { NativeSocket(request: $0) }) async throws -> RealtimeListenStream {
        let stream = RealtimeListenStream(core: core, path: path, query: query, reconnectPolicy: reconnectPolicy, socketFactory: socketFactory)
        try await stream.open()
        return stream
    }

    private func request() throws -> URLRequest {
        guard !core.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw DeepgramError.invalidConfiguration("API key is empty") }
        guard var components = URLComponents(url: core.baseURL, resolvingAgainstBaseURL: false) else {
            throw DeepgramError.invalidConfiguration("invalid base URL")
        }
        guard components.scheme == "https" || (components.scheme == "http" && ["localhost", "127.0.0.1"].contains(components.host ?? "")) else {
            throw DeepgramError.invalidConfiguration("WebSocket base URL must use HTTPS except for localhost")
        }
        components.scheme = components.scheme == "https" ? "wss" : "ws"
        components.path = path
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
                beginReceiving(from: candidate)
                return
            } catch {
                candidate.cancel()
                if attempt == reconnectPolicy.maxAttempts { throw DeepgramError.connection(String(describing: error)) }
                state = .reconnecting(attempt + 1)
                try await Task.sleep(for: reconnectPolicy.delay)
            }
        }
    }

    private func beginReceiving(from transport: any SocketTransport) {
        receiveTask = Task { [weak self, transport] in
            do {
                while !Task.isCancelled {
                    let message = try await transport.receive()
                    guard let self else { transport.cancel(); return }
                    await self.accept(message)
                }
            } catch {
                guard let self else { transport.cancel(); return }
                await self.disconnected(error)
            }
        }
    }

    private func accept(_ message: SocketMessage) {
        switch message {
        case .data(let data): emit(.unknown(type: "binary", payload: .number(Double(data.count))))
        case .text(let text):
            let data = Data(text.utf8)
            guard let raw = try? JSONDecoder().decode(JSONValue.self, from: data),
                  case .object(let object) = raw else { emit(.malformed(data)); return }
            let type: String? = if case .string(let value)? = object["type"] { value } else { nil }
            do {
                let decoder = JSONDecoder()
                let event: ListenEvent = switch type {
                case "Results": .v1Results(try decoder.decode(ListenV1_ListenV1Results.self, from: data))
                case "Metadata": .v1Metadata(try decoder.decode(ListenV1_ListenV1Metadata.self, from: data))
                case "UtteranceEnd": .v1UtteranceEnd(try decoder.decode(ListenV1_ListenV1UtteranceEnd.self, from: data))
                case "SpeechStarted": .v1SpeechStarted(try decoder.decode(ListenV1_ListenV1SpeechStarted.self, from: data))
                case "Connected": .connected(try decoder.decode(ListenV2_ListenV2Connected.self, from: data))
                case "TurnInfo": .turnInfo(try decoder.decode(ListenV2_ListenV2TurnInfo.self, from: data))
                case "ConfigureSuccess": .configureSuccess(try decoder.decode(ListenV2_ListenV2ConfigureSuccess.self, from: data))
                case "ConfigureFailure": .configureFailure(try decoder.decode(ListenV2_ListenV2ConfigureFailure.self, from: data))
                case "Error": .fatalError(try decoder.decode(ListenV2_ListenV2FatalError.self, from: data))
                default: .unknown(type: type, payload: raw)
                }
                emit(event)
                if case .fatalError(let failure) = event {
                    finish(DeepgramError.protocolViolation("\(failure.code): \(failure.description)"))
                }
            } catch { emit(.malformed(data)) }
        }
    }

    private func emit(_ event: ListenEvent) {
        if case .dropped = continuation.yield(event) {
            finish(DeepgramError.protocolViolation("event buffer overflow; consumer is too slow"))
        }
    }

    private func disconnected(_ error: Error) async {
        guard state != .closed && state != .closing else { return }
        socket?.cancel()
        if audioBytesSent == 0 && reconnectAttempts < reconnectPolicy.maxAttempts {
            reconnectAttempts += 1
            state = .reconnecting(reconnectAttempts)
            do {
                try await Task.sleep(for: reconnectPolicy.delay)
                try await open()
                return
            } catch { finish(DeepgramError.connection(String(describing: error))); return }
        }
        finish(DeepgramError.interrupted("connection ended after \(audioBytesSent) audio bytes; audio was not replayed: \(error)"))
    }

    private func finish(_ error: Error? = nil) {
        guard state != .closed else { return }
        state = .closed
        socket?.cancel()
        receiveTask?.cancel()
        continuation.finish(throwing: error)
    }

    public func send(_ audio: Data) async throws {
        if Task.isCancelled { throw DeepgramError.cancelled }
        guard state == .open, let socket else { throw DeepgramError.closed }
        guard !audio.isEmpty else { return }
        // Actor methods are reentrant across awaits; chain sends to preserve audio order.
        audioBytesSent += audio.count
        try await enqueue(.data(audio), on: socket)
    }

    public func forceEndTurn() async throws {
        guard path == "/v2/listen" else { throw DeepgramError.invalidConfiguration("ForceEndTurn requires Listen v2") }
        try await sendControl("ForceEndTurn")
    }

    public func finalize() async throws {
        guard path == "/v1/listen" else { throw DeepgramError.invalidConfiguration("Finalize requires Listen v1") }
        try await sendControl("Finalize")
    }

    private func sendControl(_ type: String) async throws {
        if Task.isCancelled { throw DeepgramError.cancelled }
        guard state == .open, let socket else { throw DeepgramError.closed }
        try await enqueue(.text("{\"type\":\"\(type)\"}"), on: socket)
    }

    private func enqueue(_ message: SocketMessage, on socket: any SocketTransport) async throws {
        let previous = sendTail
        let next = Task {
            try await previous?.value
            try await socket.send(message)
        }
        sendTail = next
        try await next.value
    }

    public func close() async {
        guard state != .closed else { return }
        state = .closing
        try? await sendTail?.value
        try? await socket?.send(.text("{\"type\":\"CloseStream\"}"))
        finish()
    }

    deinit { socket?.cancel() }
}

enum SocketMessage: Sendable { case text(String), data(Data) }

protocol SocketTransport: Sendable {
    func open() async throws
    func send(_ message: SocketMessage) async throws
    func receive() async throws -> SocketMessage
    func cancel()
}

private final class OpenObserver: NSObject, URLSessionWebSocketDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<Void, Error>?
    private var waiter: CheckedContinuation<Void, Error>?

    func wait() async throws {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            if let result { lock.unlock(); continuation.resume(with: result) }
            else { waiter = continuation; lock.unlock() }
        }
    }

    func complete(_ result: Result<Void, Error>) {
        lock.lock()
        guard self.result == nil else { lock.unlock(); return }
        self.result = result
        let continuation = waiter
        waiter = nil
        lock.unlock()
        continuation?.resume(with: result)
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        complete(.success(()))
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        complete(.failure(DeepgramError.connection("server closed during handshake: \(closeCode.rawValue)")))
    }
}

final class NativeSocket: SocketTransport, @unchecked Sendable {
    private let observer = OpenObserver()
    private let session: URLSession
    private let task: URLSessionWebSocketTask

    init(request: URLRequest) {
        session = URLSession(configuration: .default, delegate: observer, delegateQueue: nil)
        task = session.webSocketTask(with: request)
    }

    func open() async throws {
        task.resume()
        let timeout = Task { [observer] in
            try? await Task.sleep(for: .seconds(10))
            observer.complete(.failure(DeepgramError.timeout))
        }
        defer { timeout.cancel() }
        try await withTaskCancellationHandler {
            try await observer.wait()
        } onCancel: {
            observer.complete(.failure(DeepgramError.cancelled))
            task.cancel(with: .goingAway, reason: nil)
        }
    }

    func send(_ message: SocketMessage) async throws {
        switch message {
        case .text(let text): try await task.send(.string(text))
        case .data(let data): try await task.send(.data(data))
        }
    }

    func receive() async throws -> SocketMessage {
        switch try await task.receive() {
        case .string(let text): .text(text)
        case .data(let data): .data(data)
        @unknown default: throw DeepgramError.protocolViolation("unknown URLSession WebSocket message")
        }
    }

    func cancel() {
        task.cancel(with: .goingAway, reason: nil)
        session.invalidateAndCancel()
    }
}
