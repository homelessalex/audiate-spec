/// A content unit (docs/02-curriculum.md §1). Units are data, defined in data/curriculum.json.
public struct CurriculumUnit: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let patternIdPrefixes: [String]
    public let meters: [String]

    public init(id: String, title: String, patternIdPrefixes: [String], meters: [String]) {
        self.id = id
        self.title = title
        self.patternIdPrefixes = patternIdPrefixes
        self.meters = meters
    }

    public func contains(patternID: String) -> Bool {
        patternIdPrefixes.contains { patternID.hasPrefix($0) }
    }
}
