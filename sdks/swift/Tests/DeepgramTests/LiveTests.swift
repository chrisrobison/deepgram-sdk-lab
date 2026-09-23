import Foundation
import XCTest
@testable import DeepgramSDKLab

final class LiveTests: XCTestCase {
    private func key() throws -> String {
        let environment = ProcessInfo.processInfo.environment
        guard environment["DEEPGRAM_LIVE_TESTS"] == "1", let key = environment["DEEPGRAM_API_KEY"], !key.isEmpty else {
            throw XCTSkip("Set DEEPGRAM_LIVE_TESTS=1 and DEEPGRAM_API_KEY to run live tests")
        }
        return key
    }

    func testPrerecordedAndSpeech() async throws {
        let key = try key()
        let client = Deepgram(apiKey: key)
        let transcript = try await client.listen.transcribe(url: URL(string: "https://dpgr.am/spacewalk.wav")!)
        XCTAssertFalse(transcript.metadata.requestId.isEmpty)
        XCTAssertFalse(transcript.results.channels.isEmpty)
        let speech = try await client.speak.generate(text: "Hello from Deepgram SDK Lab.")
        XCTAssertFalse(speech.data.isEmpty)
        XCTAssertNotNil(speech.requestID)
    }

    func testStreamingHandshakes() async throws {
        let client = Deepgram(apiKey: try key())
        let flux = try await client.listen.v2.connect(model: .fluxGeneralEn, encoding: "linear16", sampleRate: 16_000)
        await flux.close()
        let speech = try await client.speak.v1.connect()
        await speech.close()
    }

    func testAgentHandshake() async throws {
        let client = Deepgram(apiKey: try key())
        let agent = try await client.agent.connect(configuration: .init(prompt: "Respond briefly."))
        XCTAssertFalse(agent.requestID.isEmpty)
        await agent.close()
    }
}
