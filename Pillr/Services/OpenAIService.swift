import Foundation

struct OpenAIService {
    static let shared = OpenAIService()
    
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    
    private init() {}
    
    private var apiKey: String {
        // Your OpenAI API key - replace with your actual key
        return "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"
    }
    
    func isPremiumUser() -> Bool {
        return UserDefaults.standard.bool(forKey: "is_premium_user")
    }
    
    func setPremiumStatus(_ isPremium: Bool) {
        UserDefaults.standard.set(isPremium, forKey: "is_premium_user")
    }
    
    func hasValidAPIKey() -> Bool {
        return !apiKey.isEmpty && apiKey.hasPrefix("sk-") && apiKey != "YOUR_OPENAI_API_KEY_HERE"
    }
    
    func checkMedicationInteractions(medications: [String]) async throws -> [DrugInteraction] {
        guard isPremiumUser() else {
            throw OpenAIError.premiumRequired
        }
        
        guard hasValidAPIKey() else {
            throw OpenAIError.invalidAPIKey
        }
        
        guard medications.count >= 2 else {
            throw OpenAIError.insufficientMedications
        }
        
        let medicationsJSON = try JSONSerialization.data(withJSONObject: medications, options: [])
        let medicationsString = String(data: medicationsJSON, encoding: .utf8) ?? "[]"
        
        let prompt = """
        You are a medical AI assistant specialized in drug interactions. Analyze the following medications for potential interactions:
        
        Medications: \(medicationsString)
        
        Please provide a comprehensive analysis of all potential drug interactions between these medications. For each interaction found, provide:
        
        1. The two specific drugs involved
        2. Severity level (Minor, Moderate, Major, or Contraindicated)
        3. A clear description of the interaction
        4. Recommended action or precaution
        
        Return your response as a JSON array with this exact structure:
        [
          {
            "drugA": "medication name",
            "drugB": "medication name", 
            "severity": "Minor|Moderate|Major|Contraindicated",
            "description": "detailed description of the interaction",
            "recommendedAction": "specific recommendation for the patient"
          }
        ]
        
        If no significant interactions are found, return an empty array: []
        
        Important: Only include clinically significant interactions. Be thorough but avoid false positives.
        """
        
        let requestBody = OpenAIRequest(
            model: "gpt-4",
            messages: [
                OpenAIMessage(role: "system", content: "You are a medical AI assistant specialized in drug interactions. Always respond with valid JSON only."),
                OpenAIMessage(role: "user", content: prompt)
            ],
            temperature: 0.1,
            maxTokens: 2000
        )
        
        guard let url = URL(string: baseURL) else {
            throw OpenAIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            throw OpenAIError.encodingError
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw OpenAIError.invalidAPIKey
            } else if httpResponse.statusCode == 429 {
                throw OpenAIError.rateLimitExceeded
            } else {
                throw OpenAIError.serverError(httpResponse.statusCode)
            }
        }
        
        do {
            let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            guard let content = openAIResponse.choices.first?.message.content else {
                throw OpenAIError.noContent
            }
            
            // Parse the JSON response from OpenAI
            guard let jsonData = content.data(using: .utf8) else {
                throw OpenAIError.invalidJSONResponse
            }
            
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
            throw OpenAIError.decodingError
        }
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
