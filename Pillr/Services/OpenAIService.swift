import Foundation
import SwiftUI

class OpenAIService: ObservableObject {
    private let premiumApiKey = "sk-proj-425FWRxs12VqXO4OxWXKyHMgBSMHtuyp-pOnPDihiPzBe8gyYCd3oI2W2xgEAmDIwkVbSTnF7VT3BlbkFJ_5buu1YAJyob_Lk8OSo2tEnjIKeLFdH3EZhLeyBYkkeEfIQDKnxXyB_t7ejr1c0LCkKQ11WHmoA"
    @Published var isLoading = false
    @Published var error: String?
    @Published var isPremiumMode = false
    
    // Cache for interaction results to avoid redundant API calls
    private var interactionCache: [String: DrugInteraction] = [:]
    private let cacheExpirationTime: TimeInterval = 24 * 60 * 60 // 24 hours
    private var cacheTimestamps: [String: Date] = [:]
    
    // Singleton instance
    static let shared = OpenAIService()
    
    private init() {
        // Load premium mode setting
        self.isPremiumMode = UserDefaults.standard.bool(forKey: "isPremiumMode")
        loadCache()
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
    
    // MARK: - Cache Management
    
    private func getCacheKey(drugA: String, drugB: String) -> String {
        let sortedDrugs = [drugA.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
                          drugB.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)].sorted()
        return sortedDrugs.joined(separator: "_")
    }
    
    private func isCacheValid(for key: String) -> Bool {
        guard let timestamp = cacheTimestamps[key] else { return false }
        return Date().timeIntervalSince(timestamp) < cacheExpirationTime
    }
    
    private func saveCache() {
        do {
            let encoder = JSONEncoder()
            let cacheData = try encoder.encode(interactionCache)
            let timestampData = try encoder.encode(cacheTimestamps)
            
            UserDefaults.standard.set(cacheData, forKey: "interactionCache")
            UserDefaults.standard.set(timestampData, forKey: "cacheTimestamps")
        } catch {
            print("Failed to save interaction cache: \(error)")
        }
    }
    
    private func loadCache() {
        do {
            if let cacheData = UserDefaults.standard.data(forKey: "interactionCache") {
                let decoder = JSONDecoder()
                interactionCache = try decoder.decode([String: DrugInteraction].self, from: cacheData)
            }
            
            if let timestampData = UserDefaults.standard.data(forKey: "cacheTimestamps") {
                let decoder = JSONDecoder()
                cacheTimestamps = try decoder.decode([String: Date].self, from: timestampData)
            }
        } catch {
            print("Failed to load interaction cache: \(error)")
            interactionCache = [:]
            cacheTimestamps = [:]
        }
    }
    
    func clearCache() {
        interactionCache.removeAll()
        cacheTimestamps.removeAll()
        UserDefaults.standard.removeObject(forKey: "interactionCache")
        UserDefaults.standard.removeObject(forKey: "cacheTimestamps")
    }
    
    // MARK: - Drug Interaction Checking
    
    func checkDrugInteractions(drugA: String, drugB: String) async throws -> DrugInteraction {
        let activeKey = getActiveAPIKey()
        guard let apiKey = activeKey, !apiKey.isEmpty else {
            throw InteractionError.apiKeyNotSet
        }
        
        // Check cache first
        let cacheKey = getCacheKey(drugA: drugA, drugB: drugB)
        if let cachedInteraction = interactionCache[cacheKey], isCacheValid(for: cacheKey) {
            return cachedInteraction
        }
        
        // Validate input
        let cleanDrugA = drugA.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDrugB = drugB.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanDrugA.isEmpty && !cleanDrugB.isEmpty else {
            throw InteractionError.invalidInput
        }
        
        let systemPrompt = """
        You are a medical expert assistant that provides accurate information about drug interactions. 
        Analyze the interaction between the two medications provided and respond with JSON only in this exact format:
        {
            "drugA": "name of first drug",
            "drugB": "name of second drug",
            "severity": "Minor, Moderate, Major, Contraindicated, or Unknown",
            "description": "A clear, concise 1-2 sentence description of the interaction mechanism and effects",
            "recommendedAction": "Specific actionable advice (monitor symptoms, consult doctor, avoid combination, etc.)"
        }
        
        Guidelines:
        - Use "Unknown" severity only when insufficient data exists
        - Be specific about monitoring requirements or timing considerations
        - Include relevant clinical significance
        - Keep descriptions medically accurate but accessible
        - Do not include disclaimers or text outside the JSON object
        """
        
        let userPrompt = "Analyze the drug interaction between \(cleanDrugA) and \(cleanDrugB). Consider dosage-dependent effects, timing, and clinical significance."
        
        // Attempt API call with retry logic
        let interaction = try await performAPICallWithRetry(
            apiKey: apiKey,
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            drugA: cleanDrugA,
            drugB: cleanDrugB
        )
        
        // Cache the result
        interactionCache[cacheKey] = interaction
        cacheTimestamps[cacheKey] = Date()
        saveCache()
        
        return interaction
    }
    
    private func performAPICallWithRetry(
        apiKey: String,
        systemPrompt: String,
        userPrompt: String,
        drugA: String,
        drugB: String,
        maxRetries: Int = 3
    ) async throws -> DrugInteraction {
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                return try await performAPICall(
                    apiKey: apiKey,
                    systemPrompt: systemPrompt,
                    userPrompt: userPrompt,
                    drugA: drugA,
                    drugB: drugB
                )
            } catch let error as InteractionError {
                lastError = error
                
                // Don't retry for certain errors
                switch error {
                case .apiKeyNotSet, .invalidInput, .invalidResponse:
                    throw error
                case .networkError, .apiError, .parseError:
                    if attempt == maxRetries {
                        throw error
                    }
                    // Wait before retry with exponential backoff
                    try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 1_000_000_000))
                }
            } catch {
                lastError = error
                if attempt == maxRetries {
                    throw InteractionError.networkError(error.localizedDescription)
                }
                try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 1_000_000_000))
            }
        }
        
        throw lastError ?? InteractionError.networkError("Unknown error occurred")
    }
    
    private func performAPICall(
        apiKey: String,
        systemPrompt: String,
        userPrompt: String,
        drugA: String,
        drugB: String
    ) async throws -> DrugInteraction {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30.0
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "temperature": 0.2,
            "max_tokens": 600,
            "top_p": 0.9
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw InteractionError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown API error"
            throw InteractionError.apiError(httpResponse.statusCode, errorMessage)
        }
        
        return try parseInteractionResponse(data: data, drugA: drugA, drugB: drugB)
    }
    
    private func parseInteractionResponse(data: Data, drugA: String, drugB: String) throws -> DrugInteraction {
        guard let responseJSON = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = responseJSON["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw InteractionError.parseError("Invalid API response structure")
        }
        
        // Clean the content and extract JSON
        let cleanedContent = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let interactionData = cleanedContent.data(using: .utf8) else {
            throw InteractionError.parseError("Failed to convert response to data")
        }
        
        do {
            let decoder = JSONDecoder()
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
            throw InteractionError.parseError("Failed to decode interaction data: \(error.localizedDescription)")
        }
    }

    func checkInteractionsForAllMedications(medications: [Medication]) async throws -> [DrugInteraction] {
        guard medications.count >= 2 else {
            return []
        }

        let drugNames = medications.map { $0.name }
        var foundInteractions: [DrugInteraction] = []
        var errors: [String] = []

        // Process interactions concurrently but with rate limiting
        let semaphore = AsyncSemaphore(value: 3) // Limit to 3 concurrent requests
        
        await withTaskGroup(of: (DrugInteraction?, String?).self) { group in
            for i in 0..<drugNames.count {
                for j in (i + 1)..<drugNames.count {
                    let drugA = drugNames[i]
                    let drugB = drugNames[j]
                    
                    // Skip if same drug (case-insensitive)
                    if drugA.lowercased() == drugB.lowercased() {
                        continue
                    }

                    group.addTask {
                        await semaphore.wait()
                        defer { 
                            Task { await semaphore.signal() }
                        }
                        
                        do {
                            let interaction = try await self.checkDrugInteractions(drugA: drugA, drugB: drugB)
                            return (interaction, nil)
                        } catch {
                            let errorMsg = "Error checking \(drugA) + \(drugB): \(error.localizedDescription)"
                            print(errorMsg)
                            return (nil, errorMsg)
                        }
                    }
                }
            }
            
            for await result in group {
                if let interaction = result.0 {
                    foundInteractions.append(interaction)
                }
                if let error = result.1 {
                    errors.append(error)
                }
            }
        }
        
        // Sort interactions by severity (most severe first)
        foundInteractions.sort { interaction1, interaction2 in
            let severityOrder: [DrugInteraction.InteractionSeverity] = [
                .contraindicated, .major, .moderate, .minor, .unknown
            ]
            
            guard let index1 = severityOrder.firstIndex(of: interaction1.severity),
                  let index2 = severityOrder.firstIndex(of: interaction2.severity) else {
                return false
            }
            
            return index1 < index2
        }
        
        // If there were errors but some interactions were found, log but don't throw
        if !errors.isEmpty && foundInteractions.isEmpty {
            throw InteractionError.networkError("Failed to check interactions: \(errors.joined(separator: "; "))")
        }
        
        return foundInteractions
    }
}

// MARK: - Error Handling

enum InteractionError: LocalizedError {
    case apiKeyNotSet
    case invalidInput
    case networkError(String)
    case apiError(Int, String)
    case parseError(String)
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .apiKeyNotSet:
            return "API key not configured. Please enable premium mode."
        case .invalidInput:
            return "Please enter valid medication names."
        case .networkError(let message):
            return "Network error: \(message)"
        case .apiError(let code, let message):
            return "API error (\(code)): \(message)"
        case .parseError(let message):
            return "Failed to parse response: \(message)"
        case .invalidResponse:
            return "Invalid response from server."
        }
    }
}

// MARK: - Async Semaphore for Rate Limiting

actor AsyncSemaphore {
    private var value: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []
    
    init(value: Int) {
        self.value = value
    }
    
    func wait() async {
        if value > 0 {
            value -= 1
            return
        }
        
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }
    
    func signal() {
        if waiters.isEmpty {
            value += 1
        } else {
            let waiter = waiters.removeFirst()
            waiter.resume()
        }
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
