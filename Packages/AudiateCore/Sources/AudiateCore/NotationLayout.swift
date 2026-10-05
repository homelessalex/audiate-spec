/// Drawable description of a pattern on a one-line percussion staff (docs/03-rhythm-model.md §3–4).
/// Pure geometry in points along x; the renderer (RhythmStaffView, M3) decides glyphs and y.
public struct NotationLayout: Hashable, Sendable {
    public struct Metrics: Hashable, Sendable {
        public var timeSignatureX = 6.0
        /// Where the first event starts (room for the time signature).
        public var leadingWidth = 32.0
        /// Rhythmic spacing: slot width proportional to duration…
        public var pointsPerTick = 2.5
        /// …but never narrower than a glyph plus its syllable.
        public var minSlotWidth = 22.0
        /// Gap after the barline that ends a pickup.
        public var barlineSpacing = 10.0
        /// Gap between the last slot and the final barline.
        public var finalBarlineGap = 6.0
        public var trailingWidth = 6.0

        public init() {}

        public static let standard = Metrics()
    }

    public enum Glyph: Hashable, Sendable {
        case note
        case rest
    }

    public struct Item: Hashable, Sendable {
        public let eventIndex: Int
        public let startTick: Int
        public let ticks: Int
        /// Left edge of the event's slot; the glyph is drawn at x.
        public let x: Double
        public let slotWidth: Double
        public let glyph: Glyph
        public let notation: NotationValue
        public let macrobeatIndex: Int
        public let isPickup: Bool
        /// Beam lines for this note when beamed (1 eighth, 2 sixteenth); 0 for rests and long values.
        public let beamCount: Int
        /// Flags drawn when the note is not part of a beam group.
        public internal(set) var flagCount: Int
    }

    public struct BeamGroup: Hashable, Sendable {
        public let itemIndices: [Int]
    }

    public struct Tie: Hashable, Sendable {
        public let fromItem: Int
        public let toItem: Int
    }

    public struct Tuplet: Hashable, Sendable {
        public let itemIndices: [Int]
        public let number: Int
    }

    public struct Barline: Hashable, Sendable {
        public let x: Double
        public let isFinal: Bool
    }

    public let timeSignature: TimeSignature
    public let timeSignatureX: Double
    public let items: [Item]
    public let beams: [BeamGroup]
    public let ties: [Tie]
    public let tuplets: [Tuplet]
    public let barlines: [Barline]
    public let width: Double
}
