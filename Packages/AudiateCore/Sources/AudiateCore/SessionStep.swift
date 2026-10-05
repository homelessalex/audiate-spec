public enum SessionStep: Hashable, Sendable {
    case echo(EchoBlockSpec)
    case nameSyllables(NameSyllablesSpec)
}
