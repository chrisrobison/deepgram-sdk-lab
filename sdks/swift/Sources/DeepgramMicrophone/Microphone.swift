import AVFoundation
import Foundation

private final class ConverterInput: @unchecked Sendable {
    private let lock = NSLock()
    private let buffer: AVAudioPCMBuffer
    private var used = false

    init(_ buffer: AVAudioPCMBuffer) { self.buffer = buffer }

    func take() -> AVAudioPCMBuffer? {
        lock.withLock {
            guard !used else { return nil }
            used = true
            return buffer
        }
    }
}

/// Optional example-only capture layer. The SDK core has no AVFoundation dependency.
public final class Microphone: @unchecked Sendable {
    public let chunks: AsyncStream<Data>
    public let levels: AsyncStream<Double>
    private let continuation: AsyncStream<Data>.Continuation
    private let levelContinuation: AsyncStream<Double>.Continuation
    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private var activityCount = 0
    private let stopLock = NSLock()
    private var stopped = false

    public init() {
        var receiver: AsyncStream<Data>.Continuation!
        chunks = AsyncStream(bufferingPolicy: .bufferingOldest(32)) { receiver = $0 }
        continuation = receiver
        var levelReceiver: AsyncStream<Double>.Continuation!
        levels = AsyncStream(bufferingPolicy: .bufferingNewest(1)) { levelReceiver = $0 }
        levelContinuation = levelReceiver
    }

    public func start() async throws {
        let permission = AVCaptureDevice.authorizationStatus(for: .audio)
        if permission == .notDetermined {
            let granted = await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { continuation.resume(returning: $0) }
            }
            guard granted else { throw NSError(domain: "Microphone", code: 1, userInfo: [NSLocalizedDescriptionKey: "Microphone permission denied"]) }
        } else if permission != .authorized {
            throw NSError(domain: "Microphone", code: 1, userInfo: [NSLocalizedDescriptionKey: "Microphone permission denied"])
        }
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard let target = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16_000, channels: 1, interleaved: true),
              let converter = AVAudioConverter(from: format, to: target) else {
            throw NSError(domain: "Microphone", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot convert microphone audio to linear16/16kHz"])
        }
        self.converter = converter
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in self?.process(buffer, target: target) }
        engine.prepare()
        try engine.start()
    }

    private func process(_ input: AVAudioPCMBuffer, target: AVAudioFormat) {
        guard let converter, let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: 2048) else { return }
        let provider = ConverterInput(input)
        var conversionError: NSError?
        _ = converter.convert(to: output, error: &conversionError) { _, status in
            guard let input = provider.take() else { status.pointee = .noDataNow; return nil }
            status.pointee = .haveData
            return input
        }
        guard conversionError == nil, output.frameLength > 0, let samples = output.int16ChannelData?[0] else { return }
        let bytes = Data(bytes: samples, count: Int(output.frameLength) * MemoryLayout<Int16>.size)
        if case .dropped = continuation.yield(bytes) { fputs("Microphone buffer full; audio chunk dropped\n", stderr) }
        activityCount += 1
        if activityCount % 10 == 0, let floats = input.floatChannelData?[0] {
            let count = Int(input.frameLength)
            let rms = sqrt((0..<count).reduce(0.0) { $0 + Double(floats[$1] * floats[$1]) } / Double(max(count, 1)))
            levelContinuation.yield(min(rms * 10, 1))
        }
    }

    public func stop() {
        let shouldStop = stopLock.withLock { () -> Bool in
            guard !stopped else { return false }
            stopped = true
            return true
        }
        guard shouldStop else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        continuation.finish()
        levelContinuation.finish()
    }
}
