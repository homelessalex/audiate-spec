/// Duration in ticks → written note value (docs/03-rhythm-model.md §3).
/// In every supported meter a microbeat (12 ticks) is an eighth, so one table covers all.
public enum NotationMapper {
    static let table: [Int: NotationValue] = [
        72: NotationValue(value: .half, dots: 1, tuplet: nil),
        48: NotationValue(value: .half, dots: 0, tuplet: nil),
        36: NotationValue(value: .quarter, dots: 1, tuplet: nil),
        24: NotationValue(value: .quarter, dots: 0, tuplet: nil),
        18: NotationValue(value: .eighth, dots: 1, tuplet: nil),
        12: NotationValue(value: .eighth, dots: 0, tuplet: nil),
        6: NotationValue(value: .sixteenth, dots: 0, tuplet: nil),
    ]

    static let triplet = NotationValue(value: .eighth, dots: 0, tuplet: 3)

    public static func notation(forTicks ticks: Int, in meter: Meter) throws -> NotationValue {
        if ticks == Rhythm.thirdTicks, meter.allowsThirds {
            return triplet
        }
        guard let value = table[ticks] else {
            throw RhythmError.notNotatable(meterID: meter.id, ticks: ticks)
        }
        return value
    }
}
