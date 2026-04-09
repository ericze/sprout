import Foundation
import os
import SwiftData

nonisolated final class TreasureRepository {
    private static let logger = Logger(subsystem: "sprout", category: "TreasureRepository")
    private let modelContext: ModelContext
    private let calendar: Calendar

    @MainActor
    init(
        modelContext: ModelContext,
        calendar: Calendar = .current
    ) {
        self.modelContext = modelContext
        self.calendar = calendar
    }
}

@MainActor
extension TreasureRepository {
    func createMemoryEntry(
        note: String?,
        imageLocalPaths: [String],
        isMilestone: Bool,
        createdAt: Date,
        birthDate: Date
    ) throws -> MemoryEntry {
        let normalizedNote = note?.trimmed.nilIfEmpty
        let normalizedImagePaths = imageLocalPaths
            .compactMap { $0.trimmed.nilIfEmpty }
            .prefix(TreasureLimits.maxImagesPerEntry)
        let ageInDays = max(
            calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: birthDate),
                to: calendar.startOfDay(for: createdAt)
            ).day ?? 0,
            0
        )
        let babyID = try fetchPreferredBabyID() ?? UUID()

        let entry = MemoryEntry(
            babyID: babyID,
            createdAt: createdAt,
            ageInDays: ageInDays,
            imageLocalPaths: Array(normalizedImagePaths),
            note: normalizedNote,
            isMilestone: isMilestone
        )
        modelContext.insert(entry)
        try modelContext.save()
        return entry
    }

    func fetchMemoryEntries() throws -> [MemoryEntry] {
        let descriptor = FetchDescriptor<MemoryEntry>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchWeeklyLetters() throws -> [WeeklyLetter] {
        let descriptor = FetchDescriptor<WeeklyLetter>(
            sortBy: [SortDescriptor(\.weekEnd, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchMemoryEntry(id: UUID) throws -> MemoryEntry? {
        var descriptor = FetchDescriptor<MemoryEntry>(
            predicate: #Predicate<MemoryEntry> { item in
                item.id == id
            }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func deleteMemoryEntry(id: UUID, removeImage: Bool = true) throws {
        var descriptor = FetchDescriptor<MemoryEntry>(
            predicate: #Predicate<MemoryEntry> { item in
                item.id == id
            }
        )
        descriptor.fetchLimit = 1

        guard let entry = try modelContext.fetch(descriptor).first else { return }
        let imagePaths = removeImage ? resolvedImageLocalPaths(for: entry) : []
        let tombstone = SyncDeletionTombstone(
            entityType: .memoryEntry,
            entityID: entry.id,
            remoteVersion: entry.remoteVersion,
            readyAfter: .now
        )
        tombstone.storagePaths = entry.remoteImagePaths
        modelContext.insert(tombstone)
        modelContext.delete(entry)
        try modelContext.save()

        guard removeImage else { return }

        let failedPaths = TreasurePhotoStorage.removeImages(at: imagePaths)
        if !failedPaths.isEmpty {
            Self.logger.error("Memory entry deleted but failed cleaning \(failedPaths.count, privacy: .public) image file(s)")
        }
    }

    func syncWeeklyLetter(
        for weekStart: Date,
        composer: WeeklyLetterComposer,
        generatedAt: Date
    ) throws {
        let normalizedWeekStart = calendar.startOfDay(for: weekStart)
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: normalizedWeekStart) ?? normalizedWeekStart

        let entries = try fetchEntries(in: normalizedWeekStart ... weekEnd.endOfDay(calendar: calendar))
        let existingLetter = try fetchWeeklyLetter(for: normalizedWeekStart)
        let newLetter = composer.compose(
            entries: entries,
            weekStart: normalizedWeekStart,
            weekEnd: weekEnd,
            generatedAt: generatedAt
        )

        switch (existingLetter, newLetter) {
        case let (existing?, replacement?):
            existing.weekEnd = replacement.weekEnd
            existing.density = replacement.density
            existing.collapsedText = replacement.collapsedText
            existing.expandedText = replacement.expandedText
            existing.generatedAt = replacement.generatedAt
            try modelContext.save()
        case (nil, let replacement?):
            modelContext.insert(replacement)
            try modelContext.save()
        case (let existing?, nil):
            modelContext.delete(existing)
            try modelContext.save()
        case (nil, nil):
            break
        }
    }

    private func fetchEntries(in range: ClosedRange<Date>) throws -> [MemoryEntry] {
        let descriptor = FetchDescriptor<MemoryEntry>(
            predicate: #Predicate<MemoryEntry> { item in
                item.createdAt >= range.lowerBound && item.createdAt <= range.upperBound
            },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }

    private func fetchWeeklyLetter(for weekStart: Date) throws -> WeeklyLetter? {
        var descriptor = FetchDescriptor<WeeklyLetter>(
            predicate: #Predicate<WeeklyLetter> { item in
                item.weekStart == weekStart
            }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func fetchPreferredBabyID() throws -> UUID? {
        var activeDescriptor = FetchDescriptor<BabyProfile>(
            predicate: #Predicate<BabyProfile> { profile in
                profile.isActive == true
            },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        activeDescriptor.fetchLimit = 1
        if let activeBaby = try modelContext.fetch(activeDescriptor).first {
            return activeBaby.id
        }

        var fallbackDescriptor = FetchDescriptor<BabyProfile>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        fallbackDescriptor.fetchLimit = 1
        return try modelContext.fetch(fallbackDescriptor).first?.id
    }

    private func resolvedImageLocalPaths(for entry: MemoryEntry) -> [String] {
        entry.imageLocalPaths
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

private extension Date {
    func endOfDay(calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: self)
        return calendar.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? self
    }
}
