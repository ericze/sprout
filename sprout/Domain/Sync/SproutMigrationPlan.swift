import Foundation
import SwiftData

enum SproutSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] = [
        BabyProfile.self,
        RecordItem.self,
        MemoryEntry.self,
        WeeklyLetter.self,
    ]

    @Model
    final class BabyProfile {
        var name: String
        var birthDate: Date
        var gender: Gender?
        var createdAt: Date
        var avatarPath: String?
        var isActive: Bool
        var hasCompletedOnboarding: Bool

        enum Gender: String, Codable {
            case male
            case female
        }

        init(
            name: String,
            birthDate: Date,
            gender: Gender?,
            createdAt: Date,
            avatarPath: String?,
            isActive: Bool,
            hasCompletedOnboarding: Bool
        ) {
            self.name = name
            self.birthDate = birthDate
            self.gender = gender
            self.createdAt = createdAt
            self.avatarPath = avatarPath
            self.isActive = isActive
            self.hasCompletedOnboarding = hasCompletedOnboarding
        }
    }

    @Model
    final class RecordItem {
        @Attribute(.unique) var id: UUID
        var timestamp: Date
        var type: String
        var value: Double?
        var leftNursingSeconds: Int
        var rightNursingSeconds: Int
        var subType: String?
        var imageURL: String?
        var aiSummary: String?
        var tags: [String]?
        var note: String?

        init(
            id: UUID,
            timestamp: Date,
            type: String,
            value: Double?,
            leftNursingSeconds: Int,
            rightNursingSeconds: Int,
            subType: String?,
            imageURL: String?,
            aiSummary: String?,
            tags: [String]?,
            note: String?
        ) {
            self.id = id
            self.timestamp = timestamp
            self.type = type
            self.value = value
            self.leftNursingSeconds = leftNursingSeconds
            self.rightNursingSeconds = rightNursingSeconds
            self.subType = subType
            self.imageURL = imageURL
            self.aiSummary = aiSummary
            self.tags = tags
            self.note = note
        }
    }

    @Model
    final class MemoryEntry {
        @Attribute(.unique) var id: UUID
        var createdAt: Date
        var ageInDays: Int?
        var imageLocalPath: String?
        var note: String?
        var isMilestone: Bool

        init(
            id: UUID,
            createdAt: Date,
            ageInDays: Int?,
            imageLocalPath: String?,
            note: String?,
            isMilestone: Bool
        ) {
            self.id = id
            self.createdAt = createdAt
            self.ageInDays = ageInDays
            self.imageLocalPath = imageLocalPath
            self.note = note
            self.isMilestone = isMilestone
        }
    }

    @Model
    final class WeeklyLetter {
        @Attribute(.unique) var id: UUID
        var weekStart: Date
        var weekEnd: Date
        var density: WeeklyLetterDensity
        var collapsedText: String
        var expandedText: String
        var generatedAt: Date

        init(
            id: UUID,
            weekStart: Date,
            weekEnd: Date,
            density: WeeklyLetterDensity,
            collapsedText: String,
            expandedText: String,
            generatedAt: Date
        ) {
            self.id = id
            self.weekStart = weekStart
            self.weekEnd = weekEnd
            self.density = density
            self.collapsedText = collapsedText
            self.expandedText = expandedText
            self.generatedAt = generatedAt
        }
    }
}

enum SproutSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            RecordItem.self,
            MemoryEntry.self,
            WeeklyLetter.self,
            BabyProfile.self,
            SyncDeletionTombstone.self,
            GrowthMilestoneEntry.self,
        ]
    }
}

enum SproutMigrationPlan: SchemaMigrationPlan {
    private static let emptyUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    static var schemas: [any VersionedSchema.Type] {
        [
            SproutSchemaV1.self,
            SproutSchemaV2.self,
        ]
    }

    static var stages: [MigrationStage] {
        [
            migrateV1toV2,
        ]
    }

    static let migrateV1toV2 = MigrationStage.custom(
        fromVersion: SproutSchemaV1.self,
        toVersion: SproutSchemaV2.self,
        willMigrate: { _ in
            // v1 has no sync metadata. Backfill is done after mapping to v2.
        },
        didMigrate: { context in
            try normalizeMigratedRows(in: context)
        }
    )

    private static func normalizeMigratedRows(in context: ModelContext) throws {
        var babies = try context.fetch(
            FetchDescriptor<BabyProfile>(
                sortBy: [SortDescriptor(\.createdAt, order: .forward)]
            )
        )
        var hasChanges = false

        if babies.isEmpty {
            let defaultBaby = BabyProfile()
            context.insert(defaultBaby)
            babies = [defaultBaby]
            hasChanges = true
        }

        var usedIDs = Set<UUID>()
        for baby in babies {
            var candidateID = baby.id
            if candidateID == emptyUUID || usedIDs.contains(candidateID) {
                candidateID = UUID()
                baby.id = candidateID
                hasChanges = true
            }
            usedIDs.insert(candidateID)
        }

        guard let canonicalBaby = babies.first(where: \.isActive) ?? babies.first else {
            if hasChanges {
                try context.save()
            }
            return
        }

        let canonicalBabyID = canonicalBaby.id
        for baby in babies {
            let shouldBeActive = baby.id == canonicalBabyID
            if baby.isActive != shouldBeActive {
                baby.isActive = shouldBeActive
                hasChanges = true
            }
            if baby.remoteVersion != nil {
                baby.remoteVersion = nil
                hasChanges = true
            }
            if baby.syncStateRaw != SyncState.pendingUpsert.rawValue {
                baby.syncStateRaw = SyncState.pendingUpsert.rawValue
                hasChanges = true
            }
        }

        let records = try context.fetch(FetchDescriptor<RecordItem>())
        for record in records {
            if record.babyID != canonicalBabyID {
                record.babyID = canonicalBabyID
                hasChanges = true
            }
            if record.remoteVersion != nil {
                record.remoteVersion = nil
                hasChanges = true
            }
            if record.syncStateRaw != SyncState.pendingUpsert.rawValue {
                record.syncStateRaw = SyncState.pendingUpsert.rawValue
                hasChanges = true
            }
        }

        let memories = try context.fetch(FetchDescriptor<MemoryEntry>())
        for memory in memories {
            if memory.babyID != canonicalBabyID {
                memory.babyID = canonicalBabyID
                hasChanges = true
            }
            if memory.remoteVersion != nil {
                memory.remoteVersion = nil
                hasChanges = true
            }
            if memory.syncStateRaw != SyncState.pendingUpsert.rawValue {
                memory.syncStateRaw = SyncState.pendingUpsert.rawValue
                hasChanges = true
            }
        }

        if hasChanges {
            try context.save()
        }
    }
}

enum SproutSchemaRegistry {
    static var models: [any PersistentModel.Type] {
        SproutSchemaV2.models
    }

    static var schema: Schema {
        Schema(SproutSchemaV2.models, version: SproutSchemaV2.versionIdentifier)
    }
}

enum SproutContainerFactory {
    static func make(
        schema: Schema,
        modelConfiguration: ModelConfiguration
    ) throws -> ModelContainer {
        // We explicitly provide the migration plan so container creation is
        // migration-aware even while historical schemas are introduced gradually.
        try ModelContainer(
            for: schema,
            migrationPlan: SproutMigrationPlan.self,
            configurations: [modelConfiguration]
        )
    }
}
