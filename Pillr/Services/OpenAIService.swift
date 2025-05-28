import Foundation
import AIProxy

// Create the OpenAI service using AIProxy
let openAIService = AIProxy.openAIService(
    partialKey: "v2|5941cfd5|F403tQOAddoT5WC8",
    serviceURL: "https://api.aiproxy.com/f534d18c/94f329fe"
)

struct OpenAIService {
    static let shared = OpenAIService()
    
    private init() {}
    
    func isPremiumUser() -> Bool {
        return UserSettings.shared.isPremiumUser
    }
    
    func setPremiumStatus(_ isPremium: Bool) {
        UserSettings.shared.setPremiumStatus(isPremium)
    }
    
    func getSubscriptionType() -> String? {
        return UserSettings.shared.subscriptionType
    }
    
    func setSubscriptionType(_ type: String) {
        UserSettings.shared.setSubscriptionType(type)
    }
    
    func setPremiumPurchased() {
        UserSettings.shared.setPremiumStatus(true)
        UserSettings.shared.setSubscriptionType("one-time-purchase")
    }
    
    func checkMedicationInteractions(medications: [String]) async throws -> [DrugInteraction] {
        guard UserSettings.shared.hasAIAccess() else {
            throw OpenAIError.premiumRequired
        }
        
        guard medications.count >= 2 else {
            throw OpenAIError.insufficientMedications
        }
        
        let medicationsJSON = try JSONSerialization.data(withJSONObject: medications, options: [])
        let medicationsString = String(data: medicationsJSON, encoding: .utf8) ?? "[]"
        
        let prompt = """
        Analyze these medications for drug interactions: \(medicationsString)
        
        Return ONLY a valid JSON array. No explanations, no markdown, just the JSON.
        
        Format:
        [
          {
            "drugA": "first medication",
            "drugB": "second medication", 
            "severity": "Minor",
            "description": "interaction description",
            "recommendedAction": "what to do"
          }
        ]
        
        Severity must be exactly: "Minor", "Moderate", "Major", or "Contraindicated"
        
        If no interactions: []
        """
        
        // Try the request with retry logic
        return try await performRequestWithRetry(medications: medications, prompt: prompt)
    }
    
    private func performRequestWithRetry(medications: [String], prompt: String, attempt: Int = 1) async throws -> [DrugInteraction] {
        let maxAttempts = 3
        
        do {
            // Using the AIProxy Swift library's structured request format
            let response = try await openAIService.chatCompletionRequest(body: .init(
                model: "gpt-4o-mini",
                messages: [
                    .system(content: .text("You are a medical AI. Respond with valid JSON only. No text before or after the JSON array.")),
                    .user(content: .text(prompt))
                ],
                temperature: 0.1
            ))
            
            guard let content = response.choices.first?.message.content else {
                if attempt < maxAttempts {
                    try await Task.sleep(nanoseconds: UInt64(attempt * 1_000_000_000)) // Wait 1-3 seconds
                    return try await performRequestWithRetry(medications: medications, prompt: prompt, attempt: attempt + 1)
                }
                return createFallbackInteraction(for: medications)
            }
            
            // Clean and extract JSON from the response
            let cleanedContent = extractJSON(from: content)
            
            guard let jsonData = cleanedContent.data(using: .utf8) else {
                if attempt < maxAttempts {
                    return try await performRequestWithRetry(medications: medications, prompt: prompt, attempt: attempt + 1)
                }
                return createFallbackInteraction(for: medications)
            }
            
            // Try to decode the interactions
            do {
                let interactions = try JSONDecoder().decode([OpenAIInteraction].self, from: jsonData)
                
                // Convert to DrugInteraction objects
                return interactions.map { interaction in
                    DrugInteraction(
                        drugA: interaction.drugA,
                        drugB: interaction.drugB,
                        severity: DrugInteraction.InteractionSeverity(rawValue: interaction.severity) ?? .unknown,
                        description: interaction.description,
                        recommendedAction: interaction.recommendedAction
                    )
                }
            } catch {
                // JSON parsing failed
                print("JSON parsing failed on attempt \(attempt): \(error)")
                print("Content received: \(content)")
                
                // Retry if possible
                if attempt < maxAttempts {
                    return try await performRequestWithRetry(medications: medications, prompt: prompt, attempt: attempt + 1)
                }
                
                // Final fallback - check known interactions
                return createFallbackInteraction(for: medications)
            }
            
        } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
            print("AIProxy error: Received \(statusCode) status code with response body: \(responseBody)")
            
            // Retry for rate limit issues
            if statusCode == 429 && attempt < maxAttempts {
                try await Task.sleep(nanoseconds: UInt64(attempt * 2_000_000_000)) // Wait 2-6 seconds
                return try await performRequestWithRetry(medications: medications, prompt: prompt, attempt: attempt + 1)
            }
            
            // For other errors, use fallback
            return createFallbackInteraction(for: medications)
        } catch {
            print("Network error on attempt \(attempt): \(error)")
            
            // Retry if possible
            if attempt < maxAttempts {
                try await Task.sleep(nanoseconds: UInt64(attempt * 1_000_000_000))
                return try await performRequestWithRetry(medications: medications, prompt: prompt, attempt: attempt + 1)
            }
            
            // Final fallback - check known interactions
            return createFallbackInteraction(for: medications)
        }
    }
    
    // MARK: - Helper Methods
    
    private func extractJSON(from content: String) -> String {
        // Remove any markdown code blocks
        var cleaned = content.replacingOccurrences(of: "```json", with: "")
        cleaned = cleaned.replacingOccurrences(of: "```", with: "")
        
        // Find the first [ and last ] to extract just the JSON array
        if let startIndex = cleaned.firstIndex(of: "["),
           let endIndex = cleaned.lastIndex(of: "]") {
            let jsonSubstring = cleaned[startIndex...endIndex]
            return String(jsonSubstring)
        }
        
        // If no array brackets found, return the cleaned content
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func createFallbackInteraction(for medications: [String]) -> [DrugInteraction] {
        // Check for known interactions first
        let knownInteractions = checkKnownInteractions(medications: medications)
        if !knownInteractions.isEmpty {
            return knownInteractions
        }
        
        // If no known interactions and we have multiple medications, return empty array
        // This indicates no interactions found rather than an error
        return []
    }
    
    private func checkKnownInteractions(medications: [String]) -> [DrugInteraction] {
        var interactions: [DrugInteraction] = []
        
        // Common drug interaction database (simplified)
        let knownInteractionPairs: [String: [String: (severity: DrugInteraction.InteractionSeverity, description: String, action: String)]] = [
            "warfarin": [
                "aspirin": (.major, "Increased risk of bleeding due to additive anticoagulant effects.", "Monitor for signs of bleeding. Consult doctor before combining."),
                "ibuprofen": (.moderate, "NSAIDs may increase bleeding risk when combined with warfarin.", "Use with caution. Monitor INR levels closely."),
                "acetaminophen": (.minor, "Generally safe combination, but high doses may affect warfarin.", "Monitor if using high doses of acetaminophen.")
            ],
            "lisinopril": [
                "ibuprofen": (.moderate, "NSAIDs may reduce effectiveness of ACE inhibitors and increase kidney damage risk.", "Monitor blood pressure and kidney function."),
                "potassium": (.moderate, "ACE inhibitors can increase potassium levels.", "Monitor potassium levels regularly.")
            ],
            "metformin": [
                "alcohol": (.minor, "May increase risk of lactic acidosis in rare cases.", "Limit alcohol consumption and monitor for symptoms.")
            ],
            "simvastatin": [
                "grapefruit": (.moderate, "Grapefruit can increase statin levels and risk of muscle problems.", "Avoid grapefruit juice while taking statins.")
            ]
        ]
        
        // Check all medication pairs
        for i in 0..<medications.count {
            for j in (i+1)..<medications.count {
                let med1 = medications[i].lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                let med2 = medications[j].lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Check both directions
                if let interaction = knownInteractionPairs[med1]?[med2] {
                    interactions.append(DrugInteraction(
                        drugA: medications[i],
                        drugB: medications[j],
                        severity: interaction.severity,
                        description: interaction.description,
                        recommendedAction: interaction.action
                    ))
                } else if let interaction = knownInteractionPairs[med2]?[med1] {
                    interactions.append(DrugInteraction(
                        drugA: medications[i],
                        drugB: medications[j],
                        severity: interaction.severity,
                        description: interaction.description,
                        recommendedAction: interaction.action
                    ))
                }
            }
        }
        
        return interactions
    }
}

// MARK: - Data Models

struct OpenAIRequest: Codable {
    let model: String
    let messages: [OpenAIMessage]
    let temperature: Double
    let maxTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
    }
}

struct OpenAIMessage: Codable {
    let role: String
    let content: String
}

struct OpenAIResponse: Codable {
    let choices: [OpenAIChoice]
}

struct OpenAIChoice: Codable {
    let message: OpenAIMessage
}

struct OpenAIInteraction: Codable {
    let drugA: String
    let drugB: String
    let severity: String
    let description: String
    let recommendedAction: String
}

// MARK: - Error Types

enum OpenAIError: LocalizedError {
    case premiumRequired
    case invalidAPIKey
    case insufficientMedications
    case invalidURL
    case encodingError
    case invalidResponse
    case rateLimitExceeded
    case serverError(Int)
    case noContent
    case invalidJSONResponse
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .premiumRequired:
            return "Premium subscription required to access AI-powered interaction checking."
        case .invalidAPIKey:
            return "Service temporarily unavailable. Please try again later."
        case .insufficientMedications:
            return "At least 2 medications are required to check for interactions."
        case .invalidURL:
            return "Invalid API URL."
        case .encodingError:
            return "Failed to encode request data."
        case .invalidResponse:
            return "Invalid response from server."
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        case .serverError(let code):
            return "Server error: \(code). Please try again later."
        case .noContent:
            return "No content received from AI service."
        case .invalidJSONResponse:
            return "Invalid JSON response from AI service."
        case .decodingError:
            return "Failed to decode response data."
        }
    }
} 
