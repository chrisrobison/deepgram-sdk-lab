import DeepgramSDKLab
import Foundation

@main
struct CLI {
    static func main() async {
        do {
            guard let key = ProcessInfo.processInfo.environment["DEEPGRAM_API_KEY"], !key.isEmpty else {
                throw DeepgramError.invalidConfiguration("set DEEPGRAM_API_KEY in the environment")
            }
            let args = Array(CommandLine.arguments.dropFirst())
            switch args.first {
            case "transcribe" where args.count == 2:
                let client = Deepgram(apiKey: key)
                let result = try await client.listen.transcribe(file: URL(fileURLWithPath: args[1]), contentType: "audio/wav")
                print("Request: \(result.metadata.requestId)")
                for channel in result.results.channels {
                    if let transcript = channel.alternatives?.first?.transcript { print(transcript) }
                }
            case "flux":
                try await flux(apiKey: key)
            default:
                print("Usage: deepgram-cli transcribe <wav-file> | flux")
            }
        } catch {
            fputs("Error: \(error)\n", stderr)
            exit(1)
        }
    }

    static func flux(apiKey: String) async throws {
        let model = FluxModel.fluxGeneralEn
        print("Connecting to Listen v2, model \(model.rawValue)…")
        let connection = try await Deepgram(apiKey: apiKey).listen.v2.connect(model: model, encoding: "linear16", sampleRate: 16_000, reconnectPolicy: .init(maxAttempts: 2))
        let microphone = Microphone()
        try await microphone.start()
        print("Connected; microphone active. Press Return to stop.")
        let started = ContinuousClock.now
        let eventTask = Task {
            do {
                for try await event in connection.events {
                    switch event {
                    case .connected(let message): print("Session \(message.requestId)")
                    case .turnInfo(let turn):
                        let elapsed = started.duration(to: .now).components.seconds
                        let lag = max(0, Double(elapsed) - turn.audioWindowEnd.value)
                        print("[\(turn.event)] \(turn.transcript)  (arrival lag ≈\(Int(lag * 1000)) ms)")
                    case .malformed: fputs("Malformed server event\n", stderr)
                    case .unknown(let type, _): fputs("Unknown event: \(type ?? "untyped")\n", stderr)
                    default: break
                    }
                }
            } catch { fputs("Stream ended: \(error)\n", stderr) }
            microphone.stop()
        }
        let stopTask = Task.detached {
            _ = readLine()
            microphone.stop()
            await connection.close()
        }
        do {
            for await chunk in microphone.chunks { try await connection.send(chunk) }
        } catch {
            microphone.stop()
            await connection.close()
            throw error
        }
        await eventTask.value
        stopTask.cancel()
    }
}
