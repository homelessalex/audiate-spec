import Foundation

/// Leitner state of one review item.
public struct ItemState: Codable, Hashable, Sendable {
    public let key: ItemKey
    /// 1…MasteryPolicy.reviewIntervalsDays.count
    public let box: Int
    public let dueDate: Date
    public let consecutiveFails: Int

    public init(key: ItemKey, box: Int, dueDate: Date, consecutiveFails: Int) {
        self.key = key
        self.box = box
        self.dueDate = dueDate
        self.consecutiveFails = consecutiveFails
    }
}
