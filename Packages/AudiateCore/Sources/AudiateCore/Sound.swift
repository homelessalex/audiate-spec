/// A sound the audio layer can play; it maps each case to a sample.
public enum Sound: Hashable, Sendable {
    case syllable(String)
    case neutral
    case click(accented: Bool)

    public var isVoice: Bool {
        switch self {
        case .syllable, .neutral: true
        case .click: false
        }
    }
}
