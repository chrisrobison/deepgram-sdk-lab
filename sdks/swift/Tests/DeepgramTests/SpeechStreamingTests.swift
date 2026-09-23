import Foundation
import XCTest
@testable import DeepgramSDKLab

final class SpeechStreamingTests: XCTestCase {
    func testAudioAndControlEvents() async throws {
        let socket = FakeSocket()
        let core = RESTClient(apiKey: "test", baseURL: URL(string: "https://api.deepgram.com")!, session: .shared, retryPolicy: .init(), logger: nil)
        let stream = try await RealtimeSpeechStream.connect(core: core, query: [.init(name: "model", value: "aura-2-asteria-en")], reconnectPolicy: .init(), socketFactory: { _ in socket })
        var events = stream.events.makeAsyncIterator()
        try await stream.speak("Hello")
        try await stream.flush()
        socket.push(.data(Data([1, 2])))
        socket.push(.text(#"{"type":"Metadata","request_id":"tts-id","model_name":"aura-2-asteria-en","model_version":"v1","model_uuid":"uuid"}"#))
        socket.push(.text(#"{"type":"NewMessage","value":3}"#))
        if case .audio(let data)? = try await events.next() { XCTAssertEqual(data, Data([1, 2])) }
        else { XCTFail("Expected audio") }
        if case .metadata(let metadata)? = try await events.next() { XCTAssertEqual(metadata.requestId, "tts-id") }
        else { XCTFail("Expected metadata") }
        if case .unknown(let type, _)? = try await events.next() { XCTAssertEqual(type, "NewMessage") }
        else { XCTFail("Expected unknown event") }
        await stream.close()
        do {
            try await stream.speak("late")
            XCTFail("Expected closed stream")
        } catch DeepgramError.closed {}
    }
}
