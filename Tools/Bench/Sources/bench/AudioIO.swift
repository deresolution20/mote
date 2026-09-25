import Foundation
import AVFoundation

enum AudioIO {
    /// Load any readable audio file as 16 kHz mono Float32 samples.
    static func loadMono16k(_ url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let target = AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false
        )!

        guard let converter = AVAudioConverter(from: file.processingFormat, to: target) else {
            throw NSError(domain: "bench", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "cannot convert \(file.processingFormat) to 16 kHz mono"
            ])
        }

        let inCapacity = AVAudioFrameCount(file.length)
        guard let inBuffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: max(inCapacity, 1)) else {
            return []
        }
        try file.read(into: inBuffer)

        let ratio = target.sampleRate / file.processingFormat.sampleRate
        let outCapacity = AVAudioFrameCount(Double(inBuffer.frameLength) * ratio) + 64
        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: outCapacity) else {
            return []
        }

        var fed = false
        var conversionError: NSError?
        converter.convert(to: outBuffer, error: &conversionError) { _, inputStatus in
            if fed {
                inputStatus.pointee = .endOfStream
                return nil
            }
            fed = true
            inputStatus.pointee = .haveData
            return inBuffer
        }
        if let conversionError { throw conversionError }

        guard let channel = outBuffer.floatChannelData else { return [] }
        return Array(UnsafeBufferPointer(start: channel[0], count: Int(outBuffer.frameLength)))
    }

    /// Duration of an audio file in seconds.
    static func duration(_ url: URL) -> TimeInterval {
        guard let file = try? AVAudioFile(forReading: url) else { return 0 }
        return Double(file.length) / file.fileFormat.sampleRate
    }
}
