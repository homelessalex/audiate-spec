public enum SessionStep: Hashable, Sendable {
    case echo(EchoBlockSpec)
    case nameNotation(NameNotationSpec)
    case read(ReadBlockSpec)
}
