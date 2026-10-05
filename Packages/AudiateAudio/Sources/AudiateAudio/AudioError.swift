public enum AudioError: Error, Hashable, Sendable {
    case noSamples(String)
    case mixedSampleRates(String)
    case unsupportedFormat(String)
    case bufferAllocation
    case missingSample(String)
}
