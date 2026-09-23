import Foundation
import XCTest
@testable import DeepgramSDKLab

final class VoiceAgentTests: XCTestCase {
    func testWelcomeSettingsAppliedBeforeAudio() async throws {
        let socket = FakeSocket()
        socket.push(.text(#"{"type":"Welcome","request_id":"agent-id"}"#))
        socket.push(.text(#"{"type":"SettingsApplied"}"#))
        let stream = try await VoiceAgentStream.connect(apiKey: "test", configuration: .init(prompt: "Be concise."),
            endpoint: URL(string: "wss://agent.deepgram.com/v1/agent/converse")!, socketFactory: { request in
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Token test")
                return socket
            })
        XCTAssertEqual(stream.requestID, "agent-id")
        var events = stream.events.makeAsyncIterator()
        if case .welcome? = try await events.next() {} else { XCTFail("Expected Welcome") }
        if case .settingsApplied? = try await events.next() {} else { XCTFail("Expected SettingsApplied") }
        try await stream.send(audio: Data([1, 2]))
        let sent = socket.snapshotSent()
        if case .text(let settings) = sent[0] { XCTAssertTrue(settings.contains("\"type\":\"Settings\"")) }
        else { XCTFail("Expected Settings first") }
        if case .data(let audio) = sent[1] { XCTAssertEqual(audio, Data([1, 2])) }
        else { XCTFail("Expected audio second") }
        socket.push(.data(Data([3, 4])))
        if case .audio(let audio)? = try await events.next() { XCTAssertEqual(audio, Data([3, 4])) }
        else { XCTFail("Expected agent audio") }
        await stream.close()
    }

    func testUnexpectedWelcomeFails() async throws {
        let socket = FakeSocket()
        socket.push(.text(#"{"type":"SettingsApplied"}"#))
        do {
            _ = try await VoiceAgentStream.connect(apiKey: "test", configuration: .init(prompt: "Hello"),
                endpoint: URL(string: "wss://agent.deepgram.com/v1/agent/converse")!, socketFactory: { _ in socket })
            XCTFail("Expected protocol violation")
        } catch DeepgramError.protocolViolation(let detail) {
            XCTAssertTrue(detail.contains("Welcome"))
        }
    }
}
