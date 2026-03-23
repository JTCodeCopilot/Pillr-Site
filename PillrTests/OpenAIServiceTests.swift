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
    func extractJSONHandlesObjectsAndPlainTextFallback() async throws {
        let objectContent = """
        Before
        {"medicationType":"stimulant","onsetMinutes":45}
        After
        """
        let objectExtracted = OpenAIService.shared._test_extractJSON(objectContent)
        #expect(objectExtracted == #"{"medicationType":"stimulant","onsetMinutes":45}"#)

        let plainText = "No JSON here"
        let plainExtracted = OpenAIService.shared._test_extractJSON(plainText)
        #expect(plainExtracted == "No JSON here")
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

    @Test
    func checkKnownInteractionsTrimsNamesAndReturnsEmptyForUnknownPairs() async throws {
        let trimmed = OpenAIService.shared._test_checkKnownInteractions([" Warfarin ", " aspirin "])
        #expect(trimmed.count == 1)
        #expect(trimmed.first?.severity == .major)

        let unknown = OpenAIService.shared._test_checkKnownInteractions(["Vitamin C", "Water"])
        #expect(unknown.isEmpty)
    }

    @Test
    func aiMethodsRequirePremiumBeforeDoingWork() async throws {
        clearPillrUserDefaults()
        UserSettings.shared.setPremiumStatus(false)
        UserSettings.shared.setSubscriptionType(nil)

        do {
            _ = try await OpenAIService.shared.checkMedicationInteractions(medications: ["Aspirin", "Warfarin"])
            #expect(Bool(false))
        } catch {
            guard case OpenAIError.premiumRequired = error else {
                #expect(Bool(false))
                return
            }
        }

        do {
            _ = try await OpenAIService.shared.getFocusTimingGuidance(for: "Vyvanse")
            #expect(Bool(false))
        } catch {
            guard case OpenAIError.premiumRequired = error else {
                #expect(Bool(false))
                return
            }
        }

        do {
            _ = try await OpenAIService.shared.getMedicationInfoOptions(medicationName: "Vyvanse")
            #expect(Bool(false))
        } catch {
            guard case OpenAIError.premiumRequired = error else {
                #expect(Bool(false))
                return
            }
        }
    }
}
