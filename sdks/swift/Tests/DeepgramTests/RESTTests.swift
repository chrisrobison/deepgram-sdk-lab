import Foundation
import XCTest
@testable import DeepgramSDKLab

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let handler = Self.handler else { return }
        do {
            let (response, body) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

final class RESTTests: XCTestCase {
    func client() -> Deepgram {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return Deepgram(apiKey: "test-key", session: URLSession(configuration: config))
    }

    func testTranscriptionSendsAuthAndDecodesNumericWireFields() async throws {
        let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appending(path: "../../../../tests/fixtures/prerecorded-response.json").standardizedFileURL
        let data = try Data(contentsOf: fixture)
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/v1/listen")
            XCTAssertEqual(request.url?.query, "model=nova-3&smart_format=true")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Token test-key")
            XCTAssertEqual(request.value(forHTTPHeaderField: "User-Agent"), "deepgram-sdk-lab-swift/0.1.0")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["dg-request-id": "fixture-id"])!, data)
        }
        let result = try await client().listen.transcribe(url: URL(string: "https://example.com/audio.wav")!, options: .init(smartFormat: true))
        XCTAssertEqual(result.metadata.requestId, "550e8400-e29b-41d4-a716-446655440000")
        XCTAssertEqual(result.results.channels[0].alternatives?[0].confidence?.value, 0.97)
        XCTAssertEqual(result.results.channels[0].alternatives?[0].words?[0].end?.value, 0.4)
        XCTAssertNotNil(result.metadata.modelInfo["nova-3"])
    }

    func testSpeechPreservesMetadataAndRejectsJSONSuccess() async throws {
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/v1/speak")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Token test-key")
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "audio/mpeg", "dg-request-id": "tts-id", "dg-model-name": "aura-2-asteria-en"])!, Data([1, 2, 3]))
        }
        let result = try await client().speak.generate(text: "Hello")
        XCTAssertEqual(result.data, Data([1, 2, 3]))
        XCTAssertEqual(result.requestID, "tts-id")
        XCTAssertEqual(result.modelName, "aura-2-asteria-en")
    }

    func testAuthenticationErrorPreservesRequestID() async throws {
        MockURLProtocol.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: ["dg-request-id": "error-id"])!, Data(#"{"message":"invalid key"}"#.utf8))
        }
        do {
            _ = try await client().listen.transcribe(url: URL(string: "https://example.com/audio.wav")!)
            XCTFail("Expected authentication failure")
        } catch DeepgramError.authentication(let status, let id, let message) {
            XCTAssertEqual(status, 401)
            XCTAssertEqual(id, "error-id")
            XCTAssertEqual(message, "invalid key")
        }
    }
}
