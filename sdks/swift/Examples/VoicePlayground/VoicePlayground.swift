import DeepgramMicrophone
import DeepgramSDKLab
import SwiftUI

@MainActor
final class VoiceSession: ObservableObject {
    @Published var state = "Idle"
    @Published var transcript = ""
    @Published var turn = ""
    @Published var microphoneLevel = 0.0
    @Published var arrivalLag = "—"
    @Published var requestId = "—"
    @Published var error = ""

    private var stream: RealtimeListenStream?
    private var microphone: Microphone?
    private var sendTask: Task<Void, Never>?
    private var receiveTask: Task<Void, Never>?
    private var levelTask: Task<Void, Never>?
    private var startTask: Task<Void, Never>?

    var active: Bool { state == "Connecting" || state == "Listening" }

    func start() {
        guard !active else { return }
        guard let key = ProcessInfo.processInfo.environment["DEEPGRAM_API_KEY"], !key.isEmpty else {
            error = "Set DEEPGRAM_API_KEY before launching."
            return
        }
        error = ""
        transcript = ""
        turn = ""
        arrivalLag = "—"
        requestId = "—"
        state = "Connecting"
        startTask = Task {
            do {
                let opened = try await Deepgram(apiKey: key).listen.v2.connect(
                    model: .fluxGeneralEn, encoding: "linear16", sampleRate: 16_000,
                    reconnectPolicy: .init(maxAttempts: 2)
                )
                guard !Task.isCancelled else { await opened.close(); return }
                stream = opened
                let mic = Microphone()
                microphone = mic
                try await mic.start()
                guard !Task.isCancelled else { await stop(); return }
                state = "Listening"
                let started = ContinuousClock.now
                receiveTask = Task {
                    do {
                        for try await event in opened.events {
                            switch event {
                            case .connected(let message): requestId = message.requestId
                            case .turnInfo(let info):
                                transcript = info.transcript
                                turn = info.event
                                let elapsed = started.duration(to: .now).components.seconds
                                arrivalLag = "≈\(Int(max(0, Double(elapsed) - info.audioWindowEnd.value) * 1000)) ms"
                            case .fatalError(let message): error = String(describing: message)
                            case .malformed: error = "Malformed server event"
                            default: break
                            }
                        }
                    } catch { self.error = String(describing: error) }
                    await stop()
                }
                levelTask = Task {
                    for await level in mic.levels { microphoneLevel = level }
                }
                sendTask = Task {
                    do {
                        for await chunk in mic.chunks { try await opened.send(chunk) }
                    } catch { self.error = String(describing: error) }
                    await stop()
                }
            } catch {
                self.error = String(describing: error)
                await stop()
            }
        }
    }

    func stop() async {
        guard state != "Idle" && state != "Stopping" else { return }
        state = "Stopping"
        startTask?.cancel()
        microphone?.stop()
        sendTask?.cancel()
        receiveTask?.cancel()
        levelTask?.cancel()
        if let stream { await stream.close() }
        stream = nil
        microphone = nil
        microphoneLevel = 0
        state = "Idle"
    }
}

@main
struct VoicePlayground: App {
    @StateObject private var session = VoiceSession()

    var body: some Scene {
        WindowGroup("Deepgram Voice Playground") {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Voice Playground").font(.title.bold())
                        Text("Listen v2 · flux-general-en").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(session.state).font(.callout.monospaced()).foregroundStyle(session.active ? .green : .secondary)
                }
                HStack {
                    Text("Microphone")
                    ProgressView(value: session.microphoneLevel).frame(maxWidth: .infinity)
                }
                GroupBox("Transcript") {
                    Text(session.transcript.isEmpty ? "Speak to see live transcription." : session.transcript)
                        .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
                        .textSelection(.enabled)
                }
                HStack {
                    Label(session.turn.isEmpty ? "Waiting for turn" : session.turn, systemImage: "waveform")
                    Spacer()
                    Text("Arrival lag \(session.arrivalLag)")
                }.font(.callout).foregroundStyle(.secondary)
                Text("Request \(session.requestId)").font(.caption.monospaced()).foregroundStyle(.secondary)
                    .textSelection(.enabled)
                if !session.error.isEmpty {
                    Text(session.error).foregroundStyle(.red).textSelection(.enabled)
                }
                HStack {
                    Spacer()
                    Button(session.active ? "Stop" : "Start listening") {
                        if session.active { Task { await session.stop() } } else { session.start() }
                    }.buttonStyle(.borderedProminent)
                }
            }
            .padding(24)
            .frame(minWidth: 540, minHeight: 340)
        }
    }
}
