import Foundation
import SwiftUI

struct MedicationSearchResult: Identifiable {
    var id = UUID()
    var name: String
    var description: String
}

class MedicationSearchService: ObservableObject {
    @Published var isLoading = false
    @Published var searchResults: [MedicationSearchResult] = []
    @Published var error: String?
    
    private var openAIService: OpenAIService {
        return OpenAIService.shared
    }
    
    func searchMedications(query: String) async {
        guard !query.isEmpty else {
            DispatchQueue.main.async {
                self.searchResults = []
            }
            return
        }
        
        // Use the OpenAIService to check for API key availability
        guard openAIService.hasAPIKey() else {
            DispatchQueue.main.async {
                self.error = "This feature requires premium or an API key. Please enable premium mode or add your OpenAI API key in settings."
                self.isLoading = false
            }
            return
        }
        
        let activeKey = openAIService.getActiveAPIKey()
        guard let apiKey = activeKey, !apiKey.isEmpty else {
            DispatchQueue.main.async {
                self.error = "API key not set. Please add your OpenAI API key in settings."
                self.isLoading = false
            }
            return
        }
        
        DispatchQueue.main.async {
            self.isLoading = true
            self.error = nil
        }
        
        let systemPrompt = """
        You are a helpful medical assistant that helps users identify medications based on their search. 
        For a given search term, return the most likely matching medications along with a brief description of what each medication is used for.
        Return ONLY a JSON array with the following structure:
        [
          {
            "name": "Medication Name",
            "description": "Brief description of what it treats (1-2 sentences)"
          }
        ]
        Include up to 5 potential matches, including the exact match if it exists and any medications with similar names or treatments.
        If you can't find a medication, return an empty array [].
        Make sure there are no leading or trailing spaces in the name or description fields.
        Do not include any explanations or text outside the JSON array.
        """
        
        let userPrompt = "Find medications matching: \(query)"
        
        do {
            // Basic URL request setup without custom timeouts
            let url = URL(string: "https://api.openai.com/v1/chat/completions")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            
            // Use the same model and settings as OpenAIService for consistency
            let requestBody: [String: Any] = [
                "model": "gpt-4o", // Revert to original model
                "messages": [
                    ["role": "system", "content": systemPrompt],
                    ["role": "user", "content": userPrompt]
                ],
                "temperature": 0.3,
                "max_tokens": 1000
            ]
            
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            request.httpBody = jsonData
            
            // Use the shared session which was working before
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "MedicationSearchService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            }
            
            guard httpResponse.statusCode == 200 else {
                throw NSError(domain: "MedicationSearchService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API error: \(httpResponse.statusCode)"])
            }
            
            // Parse the OpenAI response
            let responseJSON = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let choices = responseJSON?["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                throw NSError(domain: "MedicationSearchService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse API response"])
            }
            
            // Extract the JSON response from the content (removing any potential markdown code blocks)
            let cleanedContent = content
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Parse the medication data from the cleaned JSON
            let medicationsData = cleanedContent.data(using: .utf8)!
            let decoder = JSONDecoder()
            
            let decodedResults = try decoder.decode([MedicationResult].self, from: medicationsData)
            
            DispatchQueue.main.async {
                self.searchResults = decodedResults.map { result in
                    MedicationSearchResult(
                        name: result.name.trimmingCharacters(in: .whitespacesAndNewlines),
                        description: result.description.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                }
                self.isLoading = false
            }
            
        } catch {
            DispatchQueue.main.async {
                self.error = "Error: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}

// Helper struct for JSON decoding
private struct MedicationResult: Decodable {
    let name: String
    let description: String
} 