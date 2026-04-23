import Foundation
import SwiftData

nonisolated final class GrowthMilestoneRepository {
    private let modelContext: ModelContext

    @MainActor
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
}

@MainActor
extension GrowthMilestoneRepository {
    func createMilestone(
        babyID: UUID,
        title: String,
        templateKey: String? = nil,
        category: String,
        occurredAt: Date,
        note: String? = nil,
        imageLocalPath: String? = nil,
        isCustom: Bool = false
    ) throws -> GrowthMilestoneEntry {
        let entry = GrowthMilestoneEntry(
            babyID: babyID,
            templateKey: templateKey,
            title: title,
            category: category,
            occurredAt: occurredAt,
            note: note,
            imageLocalPath: imageLocalPath,
            isCustom: isCustom
        )
        modelContext.insert(entry)
        try modelContext.save()
        return entry
    }

    func fetchMilestones(for babyID: UUID) throws -> [GrowthMilestoneEntry] {
        let descriptor = FetchDescriptor<GrowthMilestoneEntry>(
            predicate: #Predicate<GrowthMilestoneEntry> { item in
                item.babyID == babyID
            },
            sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchMilestone(id: UUID) throws -> GrowthMilestoneEntry? {
        var descriptor = FetchDescriptor<GrowthMilestoneEntry>(
            predicate: #Predicate<GrowthMilestoneEntry> { item in
                item.id == id
            }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func updateMilestone(
        _ entry: GrowthMilestoneEntry,
        title: String? = nil,
        note: String? = nil,
        occurredAt: Date? = nil
    ) throws {
        if let title { entry.title = title }
        if let note { entry.note = note }
        if let occurredAt { entry.occurredAt = occurredAt }
        entry.syncStateRaw = SyncState.pendingUpsert.rawValue
        entry.updatedAt = Date()
        try modelContext.save()
    }

    func deleteMilestone(id: UUID) throws {
        var descriptor = FetchDescriptor<GrowthMilestoneEntry>(
            predicate: #Predicate<GrowthMilestoneEntry> { item in
                item.id == id
            }
        )
        descriptor.fetchLimit = 1

        guard let entry = try modelContext.fetch(descriptor).first else { return }
        modelContext.delete(entry)
        try modelContext.save()
    }
}
