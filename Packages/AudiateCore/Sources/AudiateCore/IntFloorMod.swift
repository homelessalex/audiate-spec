extension Int {
    /// Modulo that is never negative, so pickup ticks (< 0) wrap into the previous measure.
    func floorMod(_ divisor: Int) -> Int {
        let r = self % divisor
        return r < 0 ? r + divisor : r
    }
}
