import Foundation
import OSLog
import SwiftData
import UIKit

@MainActor
final class BabyRepository {
    private let modelContext: ModelContext
    private let canCreateAdditionalBaby: (Int) -> Bool
    private let logger = Logger(subsystem: "sprout", category: "BabyRepository")
    weak var activeBabyState: ActiveBabyState?

    init(
        modelContext: ModelContext,
        activeBabyState: ActiveBabyState? = nil,
        canCreateAdditionalBaby: @escaping (Int) -> Bool = { _ in true }
    ) {
        self.modelContext = modelContext
        self.canCreateAdditionalBaby = canCreateAdditionalBaby
        self.activeBabyState = activeBabyState
    }

    var activeBaby: BabyProfile? {
        do {
            return try fetchActiveBaby()
        } catch {
            recordFailure(operation: "Fetch active baby", error: error)
            return nil
        }
    }

    @discardableResult
    func createDefaultIfNeeded() -> Bool {
        do {
            guard try fetchActiveBaby() == nil else { return true }
            let baby = BabyProfile(
                id: UUID(),
                syncStateRaw: SyncState.pendingUpsert.rawValue
            )
            modelContext.insert(baby)
            try modelContext.save()
            return true
        } catch {
            recordFailure(operation: "Create default baby", error: error)
            return false
        }
    }

    func fetchBabies() throws -> [BabyProfile] {
        let descriptor = FetchDescriptor<BabyProfile>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }

    func createBaby(name: String, birthDate: Date, gender: BabyProfile.Gender? = nil) -> BabyProfile? {
        do {
            let babies = try fetchBabies()
            guard canCreateAdditionalBaby(babies.count) else {
                recordFailure(operation: "Create baby", reason: "Multi-baby entitlement is not active")
                return nil
            }

            let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let baby = BabyProfile(
                id: UUID(),
                name: normalizedName.isEmpty ? BabyProfile.defaultName : normalizedName,
                birthDate: birthDate,
                gender: gender,
                createdAt: .now,
                syncStateRaw: SyncState.pendingUpsert.rawValue,
                isActive: true
            )

            for existingBaby in babies where existingBaby.isActive {
                existingBaby.isActive = false
                markPendingUpsert(existingBaby)
            }

            modelContext.insert(baby)
            try modelContext.save()
            activeBabyState?.updateFrom(baby)
            return baby
        } catch {
            recordFailure(operation: "Create baby", error: error)
            return nil
        }
    }

    @discardableResult
    func activateBaby(id: UUID) -> Bool {
        do {
            let babies = try fetchBabies()
            guard let targetBaby = babies.first(where: { $0.id == id }) else {
                recordFailure(operation: "Activate baby", reason: "Baby not found")
                return false
            }

            for baby in babies {
                let shouldBeActive = baby.id == id
                guard baby.isActive != shouldBeActive else { continue }
                baby.isActive = shouldBeActive
                markPendingUpsert(baby)
            }

            try modelContext.save()
            activeBabyState?.updateFrom(targetBaby)
            return true
        } catch {
            recordFailure(operation: "Activate baby", error: error)
            return false
        }
    }

    @discardableResult
    func updateName(_ name: String) -> Bool {
        do {
            guard let baby = try fetchActiveBaby() else {
                recordFailure(operation: "Update baby name", reason: "No active baby found")
                return false
            }
            baby.name = name
            markPendingUpsert(baby)
            try modelContext.save()
            activeBabyState?.updateFrom(baby)
            return true
        } catch {
            recordFailure(operation: "Update baby name", error: error)
            return false
        }
    }

    @discardableResult
    func updateBirthDate(_ date: Date) -> Bool {
        do {
            guard let baby = try fetchActiveBaby() else {
                recordFailure(operation: "Update baby birth date", reason: "No active baby found")
                return false
            }
            baby.birthDate = date
            markPendingUpsert(baby)
            try modelContext.save()
            activeBabyState?.updateFrom(baby)
            return true
        } catch {
            recordFailure(operation: "Update baby birth date", error: error)
            return false
        }
    }

    @discardableResult
    func updateGender(_ gender: BabyProfile.Gender?) -> Bool {
        do {
            guard let baby = try fetchActiveBaby() else {
                recordFailure(operation: "Update baby gender", reason: "No active baby found")
                return false
            }
            baby.gender = gender
            markPendingUpsert(baby)
            try modelContext.save()
            activeBabyState?.updateFrom(baby)
            return true
        } catch {
            recordFailure(operation: "Update baby gender", error: error)
            return false
        }
    }

    @discardableResult
    func updateAvatar(_ image: UIImage?) -> Bool {
        do {
            guard let baby = try fetchActiveBaby() else {
                recordFailure(operation: "Update baby avatar", reason: "No active baby found")
                return false
            }

            let oldPath = baby.avatarPath

            if let image {
                let resized = Self.resizeImage(image, maxDimension: 512)
                guard let data = resized.jpegData(compressionQuality: 0.8) else {
                    recordFailure(operation: "Update baby avatar", reason: "JPEG encoding failed")
                    return false
                }

                try ensureAvatarDirectory()
                let fileName = "avatar-\(UUID().uuidString).jpg"
                let fileURL = avatarDirectoryURL.appendingPathComponent(fileName)
                try data.write(to: fileURL, options: .atomic)
                baby.avatarPath = fileURL.path
            } else {
                baby.avatarPath = nil
            }

            markPendingUpsert(baby)
            try modelContext.save()

            if let oldPath {
                deleteAvatarFile(at: oldPath)
            }

            activeBabyState?.updateFrom(baby)
            return true
        } catch {
            recordFailure(operation: "Update baby avatar", error: error)
            return false
        }
    }

    @discardableResult
    func markOnboardingCompleted() -> Bool {
        do {
            guard let baby = try fetchActiveBaby() else {
                recordFailure(operation: "Mark onboarding completed", reason: "No active baby found")
                return false
            }
            baby.hasCompletedOnboarding = true
            markPendingUpsert(baby)
            try modelContext.save()
            return true
        } catch {
            recordFailure(operation: "Mark onboarding completed", error: error)
            return false
        }
    }

    private func fetchActiveBaby() throws -> BabyProfile? {
        var descriptor = FetchDescriptor<BabyProfile>(
            predicate: #Predicate<BabyProfile> { $0.isActive == true }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func recordFailure(operation: String, error: Error) {
        logger.error("\(operation, privacy: .public) failed: \(String(describing: error), privacy: .public)")
    }

    private func recordFailure(operation: String, reason: String) {
        logger.error("\(operation, privacy: .public) failed: \(reason, privacy: .public)")
    }

    private func markPendingUpsert(_ baby: BabyProfile) {
        if baby.syncState != .pendingUpsert {
            baby.syncState = .pendingUpsert
        }
    }

    private var avatarDirectoryURL: URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return root.appendingPathComponent("BabyAvatars", isDirectory: true)
    }

    private func ensureAvatarDirectory() throws {
        try FileManager.default.createDirectory(
            at: avatarDirectoryURL,
            withIntermediateDirectories: true
        )
    }

    private func deleteAvatarFile(at path: String) {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            if FileManager.default.fileExists(atPath: trimmed) {
                try FileManager.default.removeItem(atPath: trimmed)
            }
        } catch {
            logger.error("Failed deleting old avatar: \(String(describing: error), privacy: .public)")
        }
    }

    private static func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        guard size.width > maxDimension || size.height > maxDimension else { return image }

        let scale = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
