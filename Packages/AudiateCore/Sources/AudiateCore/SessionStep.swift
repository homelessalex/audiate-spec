public enum SessionStep: Hashable, Sendable {
    case echo(EchoBlockSpec)
    case nameNotation(NameNotationSpec)
    case read(ReadBlockSpec)
    case holdPulse(HoldPulseSpec)
    case dictation(DictationSpec)
    case whichMeter(WhichMeterSpec)
    case meterFromNotation(MeterFromNotationSpec)
    case sameOrDifferent(SameOrDifferentSpec)
    case answerDifferently(AnswerDifferentlySpec)
    case compose(ComposeSpec)
}
