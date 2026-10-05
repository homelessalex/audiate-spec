import AudiateCore
import Foundation
import SwiftData

/// Maps LearnerProgress to/from SwiftData. Decisions stay in AudiateCore.
@MainActor
struct ProgressStore {
    let context: ModelContext

    func load() -> LearnerProgress {
        let attempts = ((try? context.fetch(FetchDescriptor<AttemptRecord>(sortBy: [SortDescriptor(\.date)]))) ?? []).compactMap(\.attempt)
        let items = ((try? context.fetch(FetchDescriptor<ItemStateRecord>())) ?? []).compactMap(\.state)
        let passes = (try? context.fetch(FetchDescriptor<LevelPassRecord>())) ?? []
        return LearnerProgress(
            attempts: attempts,
            items: Dictionary(items.map { ($0.key, $0) }, uniquingKeysWith: { a, _ in a }),
            passedAt: Dictionary(passes.compactMap { r in r.key.map { ($0, r.passedAt) } }, uniquingKeysWith: { a, _ in a })
        )
    }

    /// Persists what changed between two snapshots after recording `attempt`.
    func save(_ attempt: Attempt, before: LearnerProgress, after: LearnerProgress) {
        context.insert(AttemptRecord(attempt))
        let existing = Dictionary(((try? context.fetch(FetchDescriptor<ItemStateRecord>())) ?? []).map { ($0.id, $0) },
                                  uniquingKeysWith: { a, _ in a })
        for (key, state) in after.items where before.items[key] != state {
            if let record = existing[key.description] { record.update(from: state) } else { context.insert(ItemStateRecord(state)) }
        }
        for (key, date) in after.passedAt where before.passedAt[key] == nil {
            context.insert(LevelPassRecord(key, passedAt: date))
        }
        try? context.save()
    }
}
