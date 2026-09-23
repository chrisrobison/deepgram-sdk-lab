import Foundation

public enum DeepgramError: Error, Sendable, CustomStringConvertible {
    case invalidConfiguration(String)
    case authentication(status: Int, requestID: String?, message: String)
    case api(status: Int, requestID: String?, message: String)
    case malformedResponse(requestID: String?, detail: String)
    case transport(String)
    case connection(String)
    case protocolViolation(String)
    case closed
    case interrupted(String)
    case timeout
    case cancelled

    public var description: String {
        switch self {
        case .invalidConfiguration(let detail): "Invalid Deepgram configuration: \(detail)"
        case .authentication(let status, let id, let message): "Deepgram authentication failed (HTTP \(status), request \(id ?? "unknown")): \(message)"
        case .api(let status, let id, let message): "Deepgram API failed (HTTP \(status), request \(id ?? "unknown")): \(message)"
        case .malformedResponse(let id, let detail): "Malformed Deepgram response (request \(id ?? "unknown")): \(detail)"
        case .transport(let detail): "Deepgram transport failed: \(detail)"
        case .connection(let detail): "Deepgram WebSocket connection failed: \(detail)"
        case .protocolViolation(let detail): "Deepgram WebSocket protocol error: \(detail)"
        case .closed: "Deepgram connection is closed"
        case .interrupted(let detail): "Deepgram stream interrupted: \(detail)"
        case .timeout: "Deepgram request timed out"
        case .cancelled: "Deepgram operation cancelled"
        }
    }
}

public struct RetryPolicy: Sendable {
    public let maxAttempts: Int
    public let delay: Duration

    /// REST POST retries can repeat billable work. The default is one attempt.
    public init(maxAttempts: Int = 1, delay: Duration = .milliseconds(250)) {
        self.maxAttempts = max(1, maxAttempts)
        self.delay = delay
    }
}

public struct Deepgram: Sendable {
    public static let version = "0.1.0"
    public let listen: ListenClient
    public let speak: SpeakClient
    public let agent: AgentClient

    public init(
        apiKey: String,
        baseURL: URL = URL(string: "https://api.deepgram.com")!,
        session: URLSession = .shared,
        retryPolicy: RetryPolicy = .init(),
        logger: (@Sendable (String) -> Void)? = nil
    ) {
        let core = RESTClient(apiKey: apiKey, baseURL: baseURL, session: session, retryPolicy: retryPolicy, logger: logger)
        self.listen = ListenClient(core: core)
        self.speak = SpeakClient(core: core)
        self.agent = AgentClient(apiKey: apiKey)
    }
}

struct RESTClient: Sendable {
    let apiKey: String
    let baseURL: URL
    let session: URLSession
    let retryPolicy: RetryPolicy
    let logger: (@Sendable (String) -> Void)?

    func post(path: String, query: [URLQueryItem], body: Data, contentType: String) async throws -> (Data, HTTPURLResponse) {
        var request = try makeRequest(path: path, query: query, contentType: contentType)
        request.httpBody = body
        return try await execute(request, path: path, file: nil)
    }

    func postFile(path: String, query: [URLQueryItem], file: URL, contentType: String) async throws -> (Data, HTTPURLResponse) {
        guard file.isFileURL, (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize).map({ $0 > 0 }) == true else {
            throw DeepgramError.invalidConfiguration("audio file is empty or unreadable")
        }
        let request = try makeRequest(path: path, query: query, contentType: contentType)
        return try await execute(request, path: path, file: file)
    }

    private func makeRequest(path: String, query: [URLQueryItem], contentType: String) throws -> URLRequest {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DeepgramError.invalidConfiguration("API key is empty")
        }
        guard baseURL.scheme == "https" || baseURL.host == "localhost" || baseURL.host == "127.0.0.1" else {
            throw DeepgramError.invalidConfiguration("base URL must use HTTPS except for localhost")
        }
        guard var components = URLComponents(url: baseURL.appending(path: path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))), resolvingAgainstBaseURL: false) else {
            throw DeepgramError.invalidConfiguration("invalid base URL")
        }
        components.queryItems = query.isEmpty ? nil : query
        guard let url = components.url else { throw DeepgramError.invalidConfiguration("invalid request URL") }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("deepgram-sdk-lab-swift/\(Deepgram.version)", forHTTPHeaderField: "User-Agent")
        return request
    }

    private func execute(_ request: URLRequest, path: String, file: URL?) async throws -> (Data, HTTPURLResponse) {
        for attempt in 1...retryPolicy.maxAttempts {
            if Task.isCancelled { throw DeepgramError.cancelled }
            do {
                logger?("POST \(path) attempt \(attempt)")
                let (data, response): (Data, URLResponse)
                if let file { (data, response) = try await session.upload(for: request, fromFile: file) }
                else { (data, response) = try await session.data(for: request) }
                guard let http = response as? HTTPURLResponse else {
                    throw DeepgramError.malformedResponse(requestID: nil, detail: "missing HTTP response")
                }
                if (200...299).contains(http.statusCode) { return (data, http) }
                if (http.statusCode == 429 || http.statusCode == 503) && attempt < retryPolicy.maxAttempts {
                    try await Task.sleep(for: retryPolicy.delay)
                    continue
                }
                let id = http.value(forHTTPHeaderField: "dg-request-id")
                let message = Self.errorMessage(data) ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
                if http.statusCode == 401 || http.statusCode == 403 {
                    throw DeepgramError.authentication(status: http.statusCode, requestID: id, message: message)
                }
                throw DeepgramError.api(status: http.statusCode, requestID: id, message: message)
            } catch is CancellationError {
                throw DeepgramError.cancelled
            } catch let error as URLError {
                if error.code == .cancelled { throw DeepgramError.cancelled }
                if error.code == .timedOut { throw DeepgramError.timeout }
                if attempt < retryPolicy.maxAttempts {
                    try await Task.sleep(for: retryPolicy.delay)
                    continue
                }
                throw DeepgramError.transport(error.localizedDescription)
            }
        }
        throw DeepgramError.transport("retry attempts exhausted")
    }

    private static func errorMessage(_ data: Data) -> String? {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return (object["message"] as? String) ?? (object["err_msg"] as? String) ?? (object["error"] as? String)
        }
        return String(data: data, encoding: .utf8).flatMap { $0.isEmpty ? nil : $0 }
    }
}
