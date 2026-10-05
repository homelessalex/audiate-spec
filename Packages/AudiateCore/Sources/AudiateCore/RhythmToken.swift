/// Compact duration token used by cells.json and tools/build_patterns.py:
/// `12` note, `r12` rest, `12~` note tied into the next token.
public struct RhythmToken: Hashable, Sendable, CustomStringConvertible {
    public let ticks: Int
    public let isRest: Bool
    public let tieToNext: Bool

    public init(ticks: Int, isRest: Bool = false, tieToNext: Bool = false) {
        self.ticks = ticks
        self.isRest = isRest
        self.tieToNext = tieToNext
    }

    public static func parse(_ string: String) throws -> [RhythmToken] {
        try string.split(separator: " ").map { raw in
            var s = Substring(raw)
            let isRest = s.hasPrefix("r")
            if isRest { s = s.dropFirst() }
            let tie = s.hasSuffix("~")
            if tie { s = s.dropLast() }
            guard let ticks = Int(s), ticks > 0 else { throw RhythmError.invalidToken(String(raw)) }
            return RhythmToken(ticks: ticks, isRest: isRest, tieToNext: tie)
        }
    }

    public var description: String { (isRest ? "r" : "") + "\(ticks)" + (tieToNext ? "~" : "") }
}
