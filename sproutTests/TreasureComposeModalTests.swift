import Foundation
import Testing
@testable import sprout

struct TreasureComposeModalTests {

    @Test("Treasure compose copy resolves English strings")
    func englishCopy() {
        let service = LocalizationService(
            bundle: .main,
            locale: Locale(identifier: "en"),
            language: .english
        )

        #expect(TreasureComposeCopy.title(service: service) == "Keep Today")
        #expect(TreasureComposeCopy.close(service: service) == "Close")
        #expect(TreasureComposeCopy.save(service: service) == "Save")
        #expect(TreasureComposeCopy.photoSourceTitle(service: service) == "Add a photo")
        #expect(TreasureComposeCopy.photoSourceCamera(service: service) == "Take photo")
        #expect(TreasureComposeCopy.photoSourceLibrary(service: service) == "Choose from Library")
        #expect(TreasureComposeCopy.photoSourceLimit(maxCount: 6, service: service) == "Up to 6 photos")
        #expect(TreasureComposeCopy.photoSourceLimitMessage(maxCount: 6, service: service) == "This entry can hold up to 6 photos.")
        #expect(TreasureComposeCopy.discardTitle(service: service) == "Discard this entry?")
        #expect(TreasureComposeCopy.discardMessage(service: service) == "Nothing has been saved yet.")
        #expect(TreasureComposeCopy.continueEditing(service: service) == "Continue Editing")
        #expect(TreasureComposeCopy.discard(service: service) == "Discard")
        #expect(TreasureComposeCopy.saveFailureTitle(service: service) == "Couldn't save yet")
        #expect(TreasureComposeCopy.saveFailureMessage(service: service) == "Please try again.")
        #expect(TreasureComposeCopy.retry(service: service) == "Try Again")
        #expect(TreasureComposeCopy.backToEdit(service: service) == "Back to Edit")
        #expect(TreasureComposeCopy.photoSectionTitle(service: service) == "Photos (optional)")
        #expect(TreasureComposeCopy.removePhotoAccessibility(service: service) == "Remove current photo")
        #expect(TreasureComposeCopy.addMore(service: service) == "Add more")
        #expect(TreasureComposeCopy.emptyPhotoTitle(service: service) == "Leave a set of photos")
        #expect(TreasureComposeCopy.emptyPhotoSubtitle(maxCount: 6, service: service) == "Up to 6 photos, in the order you choose.")
        #expect(TreasureComposeCopy.noteTitle(service: service) == "A short note")
        #expect(TreasureComposeCopy.notePlaceholder(service: service) == "What would you like to remember about today?")
        #expect(TreasureComposeCopy.milestoneTitle(service: service) == "Mark as milestone")
        #expect(TreasureComposeCopy.milestoneAccessibility(service: service) == "Mark as milestone")
    }

    @Test("Treasure compose copy resolves Simplified Chinese strings")
    func simplifiedChineseCopy() {
        let service = LocalizationService(
            bundle: .main,
            locale: Locale(identifier: "zh-Hans"),
            language: .simplifiedChinese
        )

        let values = [
            TreasureComposeCopy.title(service: service),
            TreasureComposeCopy.close(service: service),
            TreasureComposeCopy.save(service: service),
            TreasureComposeCopy.photoSourceTitle(service: service),
            TreasureComposeCopy.photoSourceCamera(service: service),
            TreasureComposeCopy.photoSourceLibrary(service: service),
            TreasureComposeCopy.photoSourceLimit(maxCount: 6, service: service),
            TreasureComposeCopy.photoSourceLimitMessage(maxCount: 6, service: service),
            TreasureComposeCopy.discardTitle(service: service),
            TreasureComposeCopy.discardMessage(service: service),
            TreasureComposeCopy.continueEditing(service: service),
            TreasureComposeCopy.discard(service: service),
            TreasureComposeCopy.saveFailureTitle(service: service),
            TreasureComposeCopy.saveFailureMessage(service: service),
            TreasureComposeCopy.retry(service: service),
            TreasureComposeCopy.backToEdit(service: service),
            TreasureComposeCopy.photoSectionTitle(service: service),
            TreasureComposeCopy.removePhotoAccessibility(service: service),
            TreasureComposeCopy.addMore(service: service),
            TreasureComposeCopy.emptyPhotoTitle(service: service),
            TreasureComposeCopy.emptyPhotoSubtitle(maxCount: 6, service: service),
            TreasureComposeCopy.noteTitle(service: service),
            TreasureComposeCopy.notePlaceholder(service: service),
            TreasureComposeCopy.milestoneTitle(service: service),
            TreasureComposeCopy.milestoneAccessibility(service: service)
        ]

        #expect(values.allSatisfy { $0 != "" })
        #expect(values.allSatisfy { containsNonASCII($0) })
    }

    private func containsNonASCII(_ value: String) -> Bool {
        value.unicodeScalars.contains { $0.value > 0x7F }
    }
}
