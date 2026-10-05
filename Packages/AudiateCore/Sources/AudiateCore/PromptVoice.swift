/// How a prompt pattern is voiced: neutral syllable (AO, GA) or rhythm syllables (VA).
public enum PromptVoice: String, Codable, CaseIterable, Hashable, Sendable {
    case neutral
    case syllables
}
