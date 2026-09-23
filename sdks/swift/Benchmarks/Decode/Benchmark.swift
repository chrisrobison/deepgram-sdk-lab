import DeepgramSDKLab
import Foundation

@main
struct Benchmark {
    static func main() throws {
        guard CommandLine.arguments.count == 3, let iterations = Int(CommandLine.arguments[2]), iterations > 0 else {
            fputs("usage: deepgram-bench <fixture.json> <iterations>\n", stderr)
            exit(2)
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
        let decoder = JSONDecoder()
        var checksum = 0
        let start = Date()
        for _ in 0..<iterations {
            let result = try decoder.decode(ListenV1Response.self, from: data)
            checksum += result.results.channels.count
        }
        let seconds = Date().timeIntervalSince(start)
        print("swift decode_count=\(iterations) seconds=\(String(format: "%.4f", seconds)) per_second=\(Int(Double(iterations) / seconds)) checksum=\(checksum)")
    }
}
