import Foundation
import XCTest
@testable import DeepgramSDKLab

final class FakeSocket: SocketTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var queued: [Result<SocketMessage, Error>] = []
    private var waiter: CheckedContinuation<SocketMessage, Error>?
    private var isClosed = false
    private(set) var sent: [SocketMessage] = []
    var openError: Error?
    func snapshotSent() -> [SocketMessage] { lock.withLock { sent } }

    func open() async throws { if let openError { throw openError } }

    func send(_ message: SocketMessage) async throws {
        try lock.withLock {
            if isClosed { throw DeepgramError.closed }
            sent.append(message)
        }
    }

    func receive() async throws -> SocketMessage {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            if !queued.isEmpty {
                let next = queued.removeFirst()
                lock.unlock()
                continuation.resume(with: next)
            } else if isClosed {
                lock.unlock()
                continuation.resume(throwing: DeepgramError.closed)
            } else {
                waiter = continuation
                lock.unlock()
            }
        }
    }

    func push(_ message: SocketMessage) { pushResult(.success(message)) }
    func fail(_ error: Error) { pushResult(.failure(error)) }
    private func pushResult(_ result: Result<SocketMessage, Error>) {
        lock.lock()
        let waiting = waiter
        waiter = nil
        if waiting == nil { queued.append(result) }
        lock.unlock()
        waiting?.resume(with: result)
    }

    func cancel() {
        lock.lock()
        isClosed = true
        let waiting = waiter
        waiter = nil
        lock.unlock()
        waiting?.resume(throwing: DeepgramError.closed)
    }
}

final class RealtimeTests: XCTestCase {
    private func stream(_ socket: FakeSocket) async throws -> RealtimeListenStream {
        let core = RESTClient(apiKey: "test", baseURL: URL(string: "https://api.deepgram.com")!, session: .shared, retryPolicy: .init(), logger: nil)
        return try await RealtimeListenStream.connect(core: core, path: "/v2/listen", query: [.init(name: "model", value: "flux-general-en")], reconnectPolicy: .init(), socketFactory: { _ in socket })
    }

    func testTurnUnknownAndMalformedEvents() async throws {
        let socket = FakeSocket()
        let connection = try await stream(socket)
        var events = connection.events.makeAsyncIterator()
        socket.push(.text(#"{"type":"Connected","request_id":"id","sequence_id":0}"#))
        socket.push(.text(#"{"type":"FutureEvent","extra":1}"#))
        socket.push(.text("{malformed"))
        if case .connected(let connected)? = try await events.next() { XCTAssertEqual(connected.requestId, "id") }
        else { XCTFail("Expected Connected") }
        if case .unknown(let type, _)? = try await events.next() { XCTAssertEqual(type, "FutureEvent") }
        else { XCTFail("Expected unknown event") }
        if case .malformed? = try await events.next() {} else { XCTFail("Expected malformed event") }
        await connection.close()
    }

    func testSendAfterCloseAndRapidShutdown() async throws {
        let socket = FakeSocket()
        let connection = try await stream(socket)
        try await connection.send(Data([1, 2, 3]))
        await connection.close()
        await connection.close()
        let state = await connection.state
        XCTAssertEqual(state, .closed)
        do {
            try await connection.send(Data([4]))
            XCTFail("Expected closed error")
        } catch DeepgramError.closed {}
    }

    func testNetworkInterruptionAfterAudioIsReported() async throws {
        let socket = FakeSocket()
        let connection = try await stream(socket)
        try await connection.send(Data([1]))
        var events = connection.events.makeAsyncIterator()
        socket.fail(DeepgramError.connection("simulated interruption"))
        do {
            _ = try await events.next()
            XCTFail("Expected interrupted stream")
        } catch DeepgramError.interrupted(let detail) {
            XCTAssertTrue(detail.contains("1 audio bytes"))
        }
    }

    func testReconnectBeforeAudioAndPartialChunkOrder() async throws {
        let failed = FakeSocket()
        failed.openError = DeepgramError.connection("first attempt")
        let working = FakeSocket()
        let sequence = SocketSequence([failed, working])
        let core = RESTClient(apiKey: "test", baseURL: URL(string: "https://api.deepgram.com")!, session: .shared, retryPolicy: .init(), logger: nil)
        let connection = try await RealtimeListenStream.connect(core: core, path: "/v2/listen", query: [.init(name: "model", value: "flux-general-en")],
            reconnectPolicy: .init(maxAttempts: 1, delay: .milliseconds(1)), socketFactory: { _ in sequence.next() })
        try await connection.send(Data([1]))
        try await connection.send(Data([2]))
        let sent = working.snapshotSent()
        if case .data(let first) = sent[0] { XCTAssertEqual(first, Data([1])) } else { XCTFail("First chunk missing") }
        if case .data(let second) = sent[1] { XCTAssertEqual(second, Data([2])) } else { XCTFail("Second chunk missing") }
        await connection.close()
    }

    func testCancelledSendDoesNotWriteAudio() async throws {
        let socket = FakeSocket()
        let connection = try await stream(socket)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            try await connection.send(Data([1]))
        }
        do {
            try await task.value
            XCTFail("Expected cancellation")
        } catch DeepgramError.cancelled {}
        XCTAssertTrue(socket.snapshotSent().isEmpty)
        await connection.close()
    }
}

private final class SocketSequence: @unchecked Sendable {
    private let lock = NSLock()
    private var sockets: [FakeSocket]
    init(_ sockets: [FakeSocket]) { self.sockets = sockets }
    func next() -> FakeSocket { lock.withLock { sockets.removeFirst() } }
}
