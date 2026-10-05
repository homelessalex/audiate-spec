import AVFoundation

/// All one-shot samples, preloaded as mono Float32 at one shared sample rate.
public struct SampleBank: Sendable {
    public let sampleRate: Double
    public let samples: [String: [Float]]

    public init(sampleRate: Double, samples: [String: [Float]]) {
        self.sampleRate = sampleRate
        self.samples = samples
    }

    /// Loads every `.caf` in `directory`; the file name (without extension) is the sample name.
    public static func load(directory: URL) throws -> SampleBank {
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "caf" }
        var rate: Double?
        var samples: [String: [Float]] = [:]
        for url in files {
            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            if let rate, rate != format.sampleRate { throw AudioError.mixedSampleRates(url.lastPathComponent) }
            rate = format.sampleRate
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length)) else {
                throw AudioError.bufferAllocation
            }
            try file.read(into: buffer)
            guard let channel = buffer.floatChannelData?[0] else { throw AudioError.unsupportedFormat(url.lastPathComponent) }
            samples[url.deletingPathExtension().lastPathComponent] = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
        }
        guard let rate else { throw AudioError.noSamples(directory.path) }
        return SampleBank(sampleRate: rate, samples: samples)
    }
}
