import Foundation
import Testing
import SwiftData
@testable import sprout

@MainActor
struct GrowthStoreTests {

    @Test("save milestone refreshes timeline and shows undo toast")
    func testSaveMilestoneRefreshesAndShowsUndo() throws {
        let env = try makeTestEnvironment(now: Date(timeIntervalSince1970: 1_710_000_000))
        let store = try makeGrowthStore(environment: env)
        store.configure(modelContext: env.modelContext)
        store.handle(.onAppear)

        #expect(store.viewState.milestones.isEmpty)

        var draft = GrowthMilestoneDraft()
        draft.customTitle = "First Smile"
        draft.category = .social
        draft.isCustom = true

        store.handle(.tapAddMilestone)
        #expect(store.viewState.milestoneSheetState == .add)

        store.handle(.updateMilestoneDraft(draft))
        store.handle(.saveMilestone)

        if case .closed = store.viewState.milestoneSheetState {
            // expected
        } else {
            Issue.record("milestoneSheetState should be .closed, got \(store.viewState.milestoneSheetState)")
        }
        #expect(store.viewState.milestones.count == 1)
        let milestone = try #require(store.viewState.milestones.first)
        #expect(milestone.title == "First Smile")
        #expect(store.viewState.undoToast != nil)
    }

    @Test("delete milestone removes entry and offers undo")
    func testDeleteMilestoneRemovesAndOffersUndo() throws {
        let env = try makeTestEnvironment(now: Date(timeIntervalSince1970: 1_710_000_000))
        let store = try makeGrowthStore(environment: env)
        store.configure(modelContext: env.modelContext)
        store.handle(.onAppear)

        // First create a milestone
        var draft = GrowthMilestoneDraft()
        draft.customTitle = "First Step"
        draft.category = .motor
        draft.isCustom = true

        store.handle(.tapAddMilestone)
        store.handle(.updateMilestoneDraft(draft))
        store.handle(.saveMilestone)
        #expect(store.viewState.milestones.count == 1)

        let milestoneID = try #require(store.viewState.milestones.first?.id)

        // Delete it
        store.handle(.deleteMilestone(milestoneID))

        #expect(store.viewState.milestones.isEmpty)
        #expect(store.viewState.undoToast != nil)
        #expect(store.viewState.undoToast?.recordID == milestoneID)
    }

    @Test("undo deleted milestone restores entry")
    func testUndoDeletedMilestoneRestoresEntry() throws {
        let env = try makeTestEnvironment(now: Date(timeIntervalSince1970: 1_710_000_000))
        let store = try makeGrowthStore(environment: env)
        store.configure(modelContext: env.modelContext)
        store.handle(.onAppear)

        // Create a milestone
        var draft = GrowthMilestoneDraft()
        draft.customTitle = "First Crawl"
        draft.category = .motor
        draft.isCustom = true

        store.handle(.tapAddMilestone)
        store.handle(.updateMilestoneDraft(draft))
        store.handle(.saveMilestone)
        #expect(store.viewState.milestones.count == 1)

        let milestoneID = try #require(store.viewState.milestones.first?.id)

        // Delete it
        store.handle(.deleteMilestone(milestoneID))
        #expect(store.viewState.milestones.isEmpty)

        // Undo the delete
        store.handle(.undoDeletedMilestone)

        #expect(store.viewState.milestones.count == 1)
        let restoredMilestone = try #require(store.viewState.milestones.first)
        #expect(restoredMilestone.title == "First Crawl")
        #expect(store.viewState.undoToast == nil)
    }
}
