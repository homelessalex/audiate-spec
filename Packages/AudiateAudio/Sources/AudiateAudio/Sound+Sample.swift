import AudiateCore

extension Sound {
    /// File name in Resources/Samples (docs/05-architecture.md §1).
    public var sampleName: String {
        switch self {
        case .syllable(let s): s.lowercased()
        case .neutral: "neutral"
        case .click(let accented): accented ? "click_hi" : "click_lo"
        }
    }
}

extension SampleBank {
    public static let tapSampleName = "tap"
}
