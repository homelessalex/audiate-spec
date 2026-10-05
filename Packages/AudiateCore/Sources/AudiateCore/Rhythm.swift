/// Global constants of the tick model (docs/03-rhythm-model.md §1).
public enum Rhythm {
    /// Divisible by 2 (divisions) and lets a 2-microbeat macrobeat split into thirds (24 / 3 = 8).
    public static let ticksPerMicrobeat = 12
    /// A division: half a microbeat.
    public static let divisionTicks = ticksPerMicrobeat / 2
    /// A third of a 2-microbeat macrobeat (usual combined meter only).
    public static let thirdTicks = ticksPerMicrobeat * 2 / 3
}
