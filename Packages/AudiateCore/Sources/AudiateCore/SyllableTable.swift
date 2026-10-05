/// All beat-function syllables in one place (docs/01-methodology.md §3).
///
/// [uncertain] Unusual-meter syllables (`be`, `ba bi`) and Gordon's later revisions of division
/// syllables should be checked against *Jump Right In*; swap the table here if needed.
public struct SyllableTable: Hashable, Sendable {
    /// Microbeats of a 2-microbeat macrobeat in usual meters.
    public var usualDuple: [String]
    /// Microbeats of a 3-microbeat macrobeat in usual meters.
    public var usualTriple: [String]
    /// Microbeats of a 2-microbeat macrobeat in unusual meters.
    public var unusualDuple: [String]
    /// Microbeats of a 3-microbeat macrobeat in unusual meters.
    public var unusualTriple: [String]
    /// Half a microbeat.
    public var division: String
    /// Thirds of a 2-microbeat macrobeat (usual combined).
    public var thirds: [String]

    public static let standard = SyllableTable(
        usualDuple: ["Du", "de"],
        usualTriple: ["Du", "da", "di"],
        unusualDuple: ["Du", "be"],
        unusualTriple: ["Du", "ba", "bi"],
        division: "ta",
        thirds: ["Du", "da", "di"]
    )

    public func microbeats(macrobeatSize: Int, unusual: Bool) throws -> [String] {
        switch macrobeatSize {
        case 2: unusual ? unusualDuple : usualDuple
        case 3: unusual ? unusualTriple : usualTriple
        default: throw RhythmError.unsupportedMacrobeatSize(macrobeatSize)
        }
    }
}
