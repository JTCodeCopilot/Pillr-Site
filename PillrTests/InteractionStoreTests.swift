import Foundation
import Testing
@testable import Pillr

@MainActor
struct InteractionStoreTests {
    @Test
    func saveInteractionDedupesByDrugPair() async throws {
        clearPillrUserDefaults()
        let store = InteractionStore.shared
        resetInteractionStoreState(store)

        let first = DrugInteraction(
            drugA: "Aspirin",
            drugB: "Warfarin",
            severity: .major,
            description: "Risk",
            recommendedAction: "Monitor",
            timestamp: makeDate(year: 2025, month: 1, day: 17, hour: 8, minute: 0)
        )
        let second = DrugInteraction(
            drugA: "warfarin",
            drugB: "aspirin",
            severity: .major,
            description: "Risk updated",
            recommendedAction: "Monitor",
            timestamp: makeDate(year: 2025, month: 1, day: 17, hour: 9, minute: 0)
        )

        store.saveInteraction(first)
        store.saveInteraction(second)

        #expect(store.interactionHistory.count == 1)
        #expect(store.interactionHistory.first?.timestamp == second.timestamp)
    }

    @Test
    func filteredHistorySortsBySeverityThenDate() async throws {
        clearPillrUserDefaults()
        let store = InteractionStore.shared
        resetInteractionStoreState(store)

        let old = makeDate(year: 2025, month: 1, day: 18, hour: 8, minute: 0)
        let new = makeDate(year: 2025, month: 1, day: 18, hour: 9, minute: 0)

        store.interactionHistory = [
            DrugInteraction(drugA: "A", drugB: "B", severity: .minor, description: "", recommendedAction: "", timestamp: new),
            DrugInteraction(drugA: "C", drugB: "D", severity: .major, description: "", recommendedAction: "", timestamp: old),
            DrugInteraction(drugA: "E", drugB: "F", severity: .major, description: "", recommendedAction: "", timestamp: new),
            DrugInteraction(drugA: "G", drugB: "H", severity: .contraindicated, description: "", recommendedAction: "", timestamp: old)
        ]

        store.setSortOrder(.severityDescending)
        let sorted = store.filteredHistory

        #expect(sorted.first?.severity == .contraindicated)
        #expect(sorted[1].severity == .major)
        #expect(sorted[2].severity == .major)
        #expect(sorted[1].timestamp == new)
    }

    @Test
    func getMostCommonInteractionsCountsReversedPairs() async throws {
        clearPillrUserDefaults()
        let store = InteractionStore.shared
        resetInteractionStoreState(store)

        store.interactionHistory = [
            DrugInteraction(drugA: "A", drugB: "B", severity: .minor, description: "", recommendedAction: "", timestamp: Date()),
            DrugInteraction(drugA: "B", drugB: "A", severity: .minor, description: "", recommendedAction: "", timestamp: Date()),
            DrugInteraction(drugA: "C", drugB: "D", severity: .minor, description: "", recommendedAction: "", timestamp: Date())
        ]

        let common = store.getMostCommonInteractions(limit: 1)
        #expect(common.count == 1)
        let pair = Set([common[0].drugA.lowercased(), common[0].drugB.lowercased()])
        #expect(pair == Set(["a", "b"]))
    }

    @Test
    func searchInteractionsMatchesMultipleFields() async throws {
        clearPillrUserDefaults()
        let store = InteractionStore.shared
        resetInteractionStoreState(store)

        store.interactionHistory = [
            DrugInteraction(
                drugA: "Aspirin",
                drugB: "Warfarin",
                severity: .major,
                description: "Bleeding risk",
                recommendedAction: "Monitor INR",
                timestamp: Date()
            )
        ]

        store.searchInteractions(query: "bleeding")
        #expect(store.searchResults.count == 1)

        store.searchInteractions(query: "Monitor")
        #expect(store.searchResults.count == 1)

        store.searchInteractions(query: "Major")
        #expect(store.searchResults.count == 1)
    }
}
