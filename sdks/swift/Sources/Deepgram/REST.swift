import Foundation

public struct TranscriptionOptions: Sendable {
    public var model: String
    public var language: String?
    public var smartFormat: Bool?
    public var diarize: Bool?
    public var punctuate: Bool?
    public var additionalQuery: [URLQueryItem]

    public init(model: String = "nova-3", language: String? = nil, smartFormat: Bool? = nil, diarize: Bool? = nil, punctuate: Bool? = nil, additionalQuery: [URLQueryItem] = []) {
        self.model = model
        self.language = language
        self.smartFormat = smartFormat
        self.diarize = diarize
        self.punctuate = punctuate
        self.additionalQuery = additionalQuery
    }

    var query: [URLQueryItem] {
        var result = [URLQueryItem(name: "model", value: model)]
        if let language { result.append(.init(name: "language", value: language)) }
        if let smartFormat { result.append(.init(name: "smart_format", value: String(smartFormat))) }
        if let diarize { result.append(.init(name: "diarize", value: String(diarize))) }
        if let punctuate { result.append(.init(name: "punctuate", value: String(punctuate))) }
        return result + additionalQuery
    }
}

public struct ListenClient: Sendable {
    let core: RESTClient

    public func transcribe(url: URL, options: TranscriptionOptions = .init()) async throws -> ListenV1Response {
        let body = try JSONEncoder().encode(ListenV1RequestUrl(url: url.absoluteString))
        return try decode(try await core.post(path: GeneratedSpec.listenV1Path, query: options.query, body: body, contentType: "application/json"))
    }

    public func transcribe(audio: Data, contentType: String, options: TranscriptionOptions = .init()) async throws -> ListenV1Response {
        guard !audio.isEmpty else { throw DeepgramError.invalidConfiguration("audio is empty") }
        return try decode(try await core.post(path: GeneratedSpec.listenV1Path, query: options.query, body: audio, contentType: contentType))
    }

    public func transcribe(file: URL, contentType: String, options: TranscriptionOptions = .init()) async throws -> ListenV1Response {
        try await transcribe(audio: Data(contentsOf: file), contentType: contentType, options: options)
    }

    private func decode(_ result: (Data, HTTPURLResponse)) throws -> ListenV1Response {
        do { return try JSONDecoder().decode(ListenV1Response.self, from: result.0) }
        catch { throw DeepgramError.malformedResponse(requestID: result.1.value(forHTTPHeaderField: "dg-request-id"), detail: String(describing: error)) }
    }
}

public struct SpeechOptions: Sendable {
    public var model: String
    public var encoding: String?
    public var sampleRate: Int?
    public var container: String?

    public init(model: String = "aura-2-asteria-en", encoding: String? = nil, sampleRate: Int? = nil, container: String? = nil) {
        self.model = model
        self.encoding = encoding
        self.sampleRate = sampleRate
        self.container = container
    }

    var query: [URLQueryItem] {
        var result = [URLQueryItem(name: "model", value: model)]
        if let encoding { result.append(.init(name: "encoding", value: encoding)) }
        if let sampleRate { result.append(.init(name: "sample_rate", value: String(sampleRate))) }
        if let container { result.append(.init(name: "container", value: container)) }
        return result
    }
}

public struct SpeechAudio: Sendable {
    public let data: Data
    public let contentType: String?
    public let requestID: String?
    public let modelName: String?
}

public struct SpeakClient: Sendable {
    let core: RESTClient

    public func generate(text: String, options: SpeechOptions = .init()) async throws -> SpeechAudio {
        guard !text.isEmpty else { throw DeepgramError.invalidConfiguration("text is empty") }
        let body = try JSONEncoder().encode(SpeakV1Request(text: text))
        let (data, response) = try await core.post(path: GeneratedSpec.speakV1Path, query: options.query, body: body, contentType: "application/json")
        let id = response.value(forHTTPHeaderField: "dg-request-id")
        let mediaType = response.value(forHTTPHeaderField: "Content-Type")
        guard !data.isEmpty, mediaType?.lowercased().hasPrefix("audio/") == true else {
            throw DeepgramError.malformedResponse(requestID: id, detail: "expected nonempty audio response, got \(mediaType ?? "unknown content type")")
        }
        return SpeechAudio(data: data, contentType: mediaType, requestID: id, modelName: response.value(forHTTPHeaderField: "dg-model-name"))
    }
}
