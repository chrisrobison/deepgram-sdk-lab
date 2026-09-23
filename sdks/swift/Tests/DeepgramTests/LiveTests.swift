import Foundation
import XCTest
@testable import DeepgramSDKLab

final class LiveTests: XCTestCase {
    func testPrerecordedAndSpeech() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["DEEPGRAM_LIVE_TESTS"] == "1", let key = environment["DEEPGRAM_API_KEY"], !key.isEmpty else {
            throw XCTSkip("Set DEEPGRAM_LIVE_TESTS=1 and DEEPGRAM_API_KEY to run live tests")
        }
        let client = Deepgram(apiKey: key)
        let transcript = try await client.listen.transcribe(url: URL(string: "https://dpgr.am/spacewalk.wav")!)
        XCTAssertFalse(transcript.metadata.requestId.isEmpty)
        XCTAssertFalse(transcript.results.channels.isEmpty)
        let speech = try await client.speak.generate(text: "Hello from Deepgram SDK Lab.")
        XCTAssertFalse(speech.data.isEmpty)
        XCTAssertNotNil(speech.requestID)
    }
}
