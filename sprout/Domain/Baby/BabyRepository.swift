import Foundation
import SwiftData

@MainActor
final class BabyRepository {
    private let modelContext: ModelContext
    weak var activeBabyState: ActiveBabyState?

    init(modelContext: ModelContext, activeBabyState: ActiveBabyState? = nil) {
        self.modelContext = modelContext
        self.activeBabyState = activeBabyState
    }

    var activeBaby: BabyProfile? {
        var descriptor = FetchDescriptor<BabyProfile>(
            predicate: #Predicate<BabyProfile> { $0.isActive == true }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    func createDefaultIfNeeded() {
        guard activeBaby == nil else { return }
        let baby = BabyProfile()
        modelContext.insert(baby)
        try? modelContext.save()
    }

    func updateName(_ name: String) {
        guard let baby = activeBaby else { return }
        baby.name = name
        try? modelContext.save()
        activeBabyState?.updateFrom(baby)
    }

    func updateBirthDate(_ date: Date) {
        guard let baby = activeBaby else { return }
        baby.birthDate = date
        try? modelContext.save()
        activeBabyState?.updateFrom(baby)
    }

    func updateGender(_ gender: BabyProfile.Gender?) {
        guard let baby = activeBaby else { return }
        baby.gender = gender
        try? modelContext.save()
        activeBabyState?.updateFrom(baby)
    }

    func markOnboardingCompleted() {
        guard let baby = activeBaby else { return }
        baby.hasCompletedOnboarding = true
        try? modelContext.save()
    }
}
