import Foundation
import Testing
@testable import Pillr

struct OpenAIServiceTests {
    @Test
    func extractJSONStripsCodeFencesAndExtraText() async throws {
        let content = """
        Here is the result:
        ```json
        [
          {"drugA":"A","drugB":"B","severity":"Minor","description":"d","recommendedAction":"r"}
        ]
        ```
        Thanks!
        """
        let extracted = OpenAIService.shared._test_extractJSON(content)
        #expect(extracted.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("[") == true)
        #expect(extracted.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("]") == true)
    }

    @Test
    func checkKnownInteractionsDetectsPairRegardlessOfOrder() async throws {
        let interactions = OpenAIService.shared._test_checkKnownInteractions(["Warfarin", "Ibuprofen"])
        #expect(interactions.count == 1)
        #expect(interactions.first?.severity == .moderate)

        let reversed = OpenAIService.shared._test_checkKnownInteractions(["ibuprofen", "warfarin"])
        #expect(reversed.count == 1)
        #expect(reversed.first?.severity == .moderate)
    }
}
