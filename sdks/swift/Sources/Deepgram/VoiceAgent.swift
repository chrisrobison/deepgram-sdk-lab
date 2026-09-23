import Foundation

/// A small, typed configuration for Deepgram-hosted listen/speak and OpenAI think.
/// More specialized providers can be supplied through `additionalAgentFields`.
public struct AgentConfiguration: Sendable {
    public var prompt: String
    public var greeting: String?
    public var listenModel: String
    public var speakModel: String
    public var thinkModel: String
    public var inputSampleRate: Int
    public var outputSampleRate: Int
    public var additionalAgentFields: [String: JSONValue]

    public init(prompt: String, greeting: String? = nil, listenModel: String = "nova-3",
                speakModel: String = "aura-2-asteria-en", thinkModel: String = "gpt-4o-mini",
                inputSampleRate: Int = 16_000, outputSampleRate: Int = 24_000,
                additionalAgentFields: [String: JSONValue] = [:]) {
        self.prompt = prompt
        self.greeting = greeting
        self.listenModel = listenModel
        self.speakModel = speakModel
        self.thinkModel = thinkModel
        self.inputSampleRate = inputSampleRate
        self.outputSampleRate = outputSampleRate
        self.additionalAgentFields = additionalAgentFields
    }

    func message() throws -> String {
        guard !prompt.isEmpty, inputSampleRate > 0, outputSampleRate > 0 else {
            throw DeepgramError.invalidConfiguration("Agent prompt and sample rates must be nonempty/positive")
        }
        var agent: [String: JSONValue] = [:]
        agent["listen"] = .object(["provider": .object(["type": .string("deepgram"), "version": .string("v1"), "model": .string(listenModel)])])
        agent["speak"] = .object(["provider": .object(["type": .string("deepgram"), "version": .string("v1"), "model": .string(speakModel)])])
        agent["think"] = .object(["provider": .object(["type": .string("open_ai"), "model": .string(thinkModel)]), "prompt": .string(prompt)])
        if let greeting { agent["greeting"] = .string(greeting) }
        for (key, value) in additionalAgentFields { agent[key] = value }
        let payload: JSONValue = .object([
            "type": .string("Settings"),
            "audio": .object([
                "input": .object(["encoding": .string("linear16"), "sample_rate": .number(Double(inputSampleRate))]),
                "output": .object(["encoding": .string("linear16"), "sample_rate": .number(Double(outputSampleRate)), "container": .string("none")]),
            ]),
            "agent": .object(agent),
        ])
        return String(decoding: try JSONEncoder().encode(payload), as: UTF8.self)
    }
}

public enum AgentEvent: Sendable {
    case welcome(AgentV1_AgentV1Welcome)
    case settingsApplied(AgentV1_AgentV1SettingsApplied)
    case conversationText(AgentV1_AgentV1ConversationText)
    case userStartedSpeaking(AgentV1_AgentV1UserStartedSpeaking)
    case agentThinking(AgentV1_AgentV1AgentThinking)
    case latencyReport(AgentV1_AgentV1LatencyReport)
    case agentAudioDone(AgentV1_AgentV1AgentAudioDone)
    case functionCallRequest(AgentV1_AgentV1FunctionCallRequest)
    case warning(AgentV1_AgentV1Warning)
    case audio(Data)
    case unknown(type: String?, payload: JSONValue)
    case malformed(Data)
}

public struct AgentClient: Sendable {
    let apiKey: String

    public func connect(configuration: AgentConfiguration,
                        endpoint: URL = URL(string: "wss://agent.deepgram.com/v1/agent/converse")!) async throws -> VoiceAgentStream {
        try await VoiceAgentStream.connect(apiKey: apiKey, configuration: configuration, endpoint: endpoint)
    }
}

public actor VoiceAgentStream {
    public nonisolated let events: AsyncThrowingStream<AgentEvent, Error>
    public nonisolated let requestID: String
    public private(set) var state: ConnectionState = .open
    private let socket: any SocketTransport
    private var continuation: AsyncThrowingStream<AgentEvent, Error>.Continuation
    private var receiveTask: Task<Void, Never>?
    private var sendTail: Task<Void, Error>?

    private init(socket: any SocketTransport, welcome: AgentV1_AgentV1Welcome,
                 applied: AgentV1_AgentV1SettingsApplied) {
        self.socket = socket
        self.requestID = welcome.requestId
        var receiver: AsyncThrowingStream<AgentEvent, Error>.Continuation!
        events = AsyncThrowingStream(bufferingPolicy: .bufferingNewest(128)) { receiver = $0 }
        continuation = receiver
        continuation.yield(.welcome(welcome))
        continuation.yield(.settingsApplied(applied))
    }

    static func connect(apiKey: String, configuration: AgentConfiguration, endpoint: URL,
                        socketFactory: @escaping @Sendable (URLRequest) -> any SocketTransport = { NativeSocket(request: $0) }) async throws -> VoiceAgentStream {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw DeepgramError.invalidConfiguration("API key is empty") }
        guard endpoint.scheme == "wss" || (endpoint.scheme == "ws" && ["localhost", "127.0.0.1"].contains(endpoint.host ?? "")) else {
            throw DeepgramError.invalidConfiguration("Agent endpoint must use WSS except for localhost")
        }
        let settings = try configuration.message()
        var request = URLRequest(url: endpoint)
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("deepgram-sdk-lab-swift/\(Deepgram.version)", forHTTPHeaderField: "User-Agent")
        let socket = socketFactory(request)
        do {
            try await socket.open()
            let first = try await receiveHandshake(socket)
            guard case .text(let welcomeText) = first,
                  let welcome = try? JSONDecoder().decode(AgentV1_AgentV1Welcome.self, from: Data(welcomeText.utf8)),
                  welcome.type == "Welcome" else {
                throw DeepgramError.protocolViolation("Agent expected Welcome before Settings")
            }
            try await socket.send(.text(settings))
            let second = try await receiveHandshake(socket)
            guard case .text(let appliedText) = second,
                  let applied = try? JSONDecoder().decode(AgentV1_AgentV1SettingsApplied.self, from: Data(appliedText.utf8)),
                  applied.type == "SettingsApplied" else {
                throw DeepgramError.protocolViolation("Agent expected SettingsApplied before audio")
            }
            let stream = VoiceAgentStream(socket: socket, welcome: welcome, applied: applied)
            await stream.startReceiving()
            return stream
        } catch {
            socket.cancel()
            throw error
        }
    }

    private static func receiveHandshake(_ socket: any SocketTransport) async throws -> SocketMessage {
        let deadline = AgentDeadline()
        let timer = Task {
            do {
                try await Task.sleep(for: .seconds(10))
                deadline.fire()
                socket.cancel()
            } catch {}
        }
        defer { timer.cancel() }
        do { return try await socket.receive() }
        catch {
            if deadline.didFire { throw DeepgramError.timeout }
            throw error
        }
    }

    private func startReceiving() {
        receiveTask = Task { [weak self, socket] in
            do {
                while !Task.isCancelled {
                    let message = try await socket.receive()
                    guard let self else { socket.cancel(); return }
                    await self.accept(message)
                }
            } catch {
                guard let self else { socket.cancel(); return }
                await self.finish(DeepgramError.interrupted("Agent session ended: \(error)"))
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
                if type == "Error" {
                    let error = try decoder.decode(AgentV1_AgentV1Error.self, from: data)
                    finish(DeepgramError.protocolViolation("Agent \(error.code): \(error.description)"))
                    return
                }
                let event: AgentEvent = switch type {
                case "ConversationText": .conversationText(try decoder.decode(AgentV1_AgentV1ConversationText.self, from: data))
                case "UserStartedSpeaking": .userStartedSpeaking(try decoder.decode(AgentV1_AgentV1UserStartedSpeaking.self, from: data))
                case "AgentThinking": .agentThinking(try decoder.decode(AgentV1_AgentV1AgentThinking.self, from: data))
                case "LatencyReport": .latencyReport(try decoder.decode(AgentV1_AgentV1LatencyReport.self, from: data))
                case "AgentAudioDone": .agentAudioDone(try decoder.decode(AgentV1_AgentV1AgentAudioDone.self, from: data))
                case "FunctionCallRequest": .functionCallRequest(try decoder.decode(AgentV1_AgentV1FunctionCallRequest.self, from: data))
                case "Warning": .warning(try decoder.decode(AgentV1_AgentV1Warning.self, from: data))
                default: .unknown(type: type, payload: raw)
                }
                emit(event)
            } catch { emit(.malformed(data)) }
        }
    }

    private func emit(_ event: AgentEvent) {
        if case .dropped = continuation.yield(event) {
            finish(DeepgramError.protocolViolation("Agent event buffer overflow"))
        }
    }

    private func finish(_ error: Error? = nil) {
        guard state != .closed else { return }
        state = .closed
        socket.cancel()
        receiveTask?.cancel()
        continuation.finish(throwing: error)
    }

    public func send(audio: Data) async throws {
        guard !audio.isEmpty else { return }
        try await send(.data(audio))
    }

    /// Sends a documented Agent JSON control message for provider-specific flows.
    public func send(control: JSONValue) async throws {
        guard case .object = control else { throw DeepgramError.invalidConfiguration("Agent control message must be a JSON object") }
        let data = try JSONEncoder().encode(control)
        try await send(.text(String(decoding: data, as: UTF8.self)))
    }

    private func send(_ message: SocketMessage) async throws {
        if Task.isCancelled { throw DeepgramError.cancelled }
        guard state == .open else { throw DeepgramError.closed }
        let previous = sendTail
        let next = Task { [socket] in
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
        finish()
    }

    deinit { socket.cancel() }
}

private final class AgentDeadline: @unchecked Sendable {
    private let lock = NSLock()
    private var fired = false
    var didFire: Bool { lock.withLock { fired } }
    func fire() { lock.withLock { fired = true } }
}
