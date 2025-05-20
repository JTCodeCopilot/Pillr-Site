import Foundation
import SwiftUI

class OpenAIService: ObservableObject {
    private let premiumApiKey = "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" // Replace with your actual API key
    @Published var isLoading = false
    @Published var error: String?
    @Published var isPremiumMode = false
    
    // Singleton instance
    static let shared = OpenAIService()
    
    private init() {
        // Load premium mode setting
        self.isPremiumMode = UserDefaults.standard.bool(forKey: "isPremiumMode")
    }
    
    func hasAPIKey() -> Bool {
        return isPremiumMode
    }
    
    func getActiveAPIKey() -> String? {
        return isPremiumMode ? premiumApiKey : nil
    }
    
    func enablePremiumMode() {
        self.isPremiumMode = true
        UserDefaults.standard.set(true, forKey: "isPremiumMode")
    }
    
    func disablePremiumMode() {
        self.isPremiumMode = false
        UserDefaults.standard.set(false, forKey: "isPremiumMode")
    }
    
    func checkDrugInteractions(drugA: String, drugB: String) async throws -> DrugInteraction {
        let activeKey = getActiveAPIKey()
        guard let apiKey = activeKey, !apiKey.isEmpty else {
            throw NSError(domain: "OpenAIService", code: 401, userInfo: [NSLocalizedDescriptionKey: "API key not set"])
        }
        
        let systemPrompt = """
        You are a helpful assistant that provides information about potential interactions between medications. 
        Respond with JSON only in the exact format shown below:
        {
            "drugA": "name of first drug",
            "drugB": "name of second drug",
            "severity": "Minor, Moderate, Major, Contraindicated, or Unknown",
            "description": "A concise 1-2 sentence description of the interaction",
            "recommendedAction": "What the patient should do (talk to doctor, monitor for side effects, etc.)"
        }
        
        Make your response brief but medically accurate. If you're unsure, label severity as "Unknown" 
        and recommend consulting a healthcare provider. Do not include any disclaimers or additional text
        outside the JSON object.
        """
        
        let userPrompt = "What is the interaction between \(drugA) and \(drugB)?"
        
        // Create the request to OpenAI API
        // Create the request to OpenAI API (reverted to original code)
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o", // Reverted to original model
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "temperature": 0.3,
            "max_tokens": 500
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "OpenAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "OpenAIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API error: \(httpResponse.statusCode)"])
        }
        
        // Parse the OpenAI response
        let responseJSON = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let choices = responseJSON?["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw NSError(domain: "OpenAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse API response"])
        }
        
        // Extract the JSON response from the content (removing any potential markdown code blocks)
        let cleanedContent = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Parse the interaction data from the cleaned JSON
        let interactionData = cleanedContent.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        do {
            let interactionInfo = try decoder.decode(InteractionInfo.self, from: interactionData)
            let severityEnum = DrugInteraction.InteractionSeverity(rawValue: interactionInfo.severity) ?? .unknown
            
            return DrugInteraction(
                id: UUID(),
                drugA: interactionInfo.drugA,
                drugB: interactionInfo.drugB,
                severity: severityEnum,
                description: interactionInfo.description,
                recommendedAction: interactionInfo.recommendedAction
            )
        } catch {
            throw NSError(domain: "OpenAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse interaction data: \(error.localizedDescription)"])
        }
    }

    func checkInteractionsForAllMedications(medications: [Medication]) async throws -> [DrugInteraction] {
        var foundInteractions: [DrugInteraction] = []
        guard medications.count >= 2 else {
            // Not enough medications to check for interactions
            return foundInteractions
        }

        // Create a list of drug names
        let drugNames = medications.map { $0.name }

        // Iterate through all unique pairs of medications
        for i in 0..<drugNames.count {
            for j in (i + 1)..<drugNames.count {
                let drugA = drugNames[i]
                let drugB = drugNames[j]
                
                // Avoid checking a drug against itself if somehow names are duplicated (though medications list should be unique by ID)
                if drugA.lowercased() == drugB.lowercased() {
                    continue
                }

                do {
                    let interaction = try await checkDrugInteractions(drugA: drugA, drugB: drugB)
                    // Filter out 'Unknown' or 'Minor' interactions if desired, or handle all
                    // For now, let's include all found interactions
                    foundInteractions.append(interaction)
                } catch {
                    // Log or handle individual check errors, e.g., API errors for a specific pair
                    print("Error checking interaction between \(drugA) and \(drugB): \(error.localizedDescription)")
                    // Optionally, you could rethrow the error or collect these errors to inform the user
                }
            }
        }
        return foundInteractions
    }
}

// Helper struct for JSON decoding
private struct InteractionInfo: Decodable {
    let drugA: String
    let drugB: String
    let severity: String
    let description: String
    let recommendedAction: String
} 
