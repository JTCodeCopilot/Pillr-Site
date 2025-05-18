import SwiftUI
import Combine

class InteractionStore: ObservableObject {
    @Published var interactionHistory: [DrugInteraction] = []
    @Published var searchResults: [DrugInteraction] = []
    @Published var recentSearches: [String] = []
    @Published var isSearching = false
    
    private let historyKey = "interactionHistoryData"
    private let recentSearchesKey = "recentSearchesData"
    private let maxRecentSearches = 10
    
    // Singleton instance
    static let shared = InteractionStore()
    
    private init() {
        loadInteractionHistory()
        loadRecentSearches()
    }
    
    // MARK: - Persistence
    
    func saveInteraction(_ interaction: DrugInteraction) {
        // Add to the top of the history
        interactionHistory.insert(interaction, at: 0)
        saveInteractionHistory()
        
        // Save the search term
        let searchTerm = "\(interaction.drugA) and \(interaction.drugB)"
        addRecentSearch(searchTerm)
    }
    
    private func saveInteractionHistory() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(interactionHistory)
            UserDefaults.standard.set(data, forKey: historyKey)
        } catch {
            print("Error saving interaction history: \(error)")
        }
    }
    
    private func loadInteractionHistory() {
        if let data = UserDefaults.standard.data(forKey: historyKey) {
            do {
                let decoder = JSONDecoder()
                interactionHistory = try decoder.decode([DrugInteraction].self, from: data)
            } catch {
                print("Error loading interaction history: \(error)")
                interactionHistory = []
            }
        }
    }
    
    // MARK: - Recent Searches
    
    func addRecentSearch(_ search: String) {
        // Remove if already exists to prevent duplicates
        recentSearches.removeAll { $0.lowercased() == search.lowercased() }
        
        // Add to the top
        recentSearches.insert(search, at: 0)
        
        // Limit to max number of recent searches
        if recentSearches.count > maxRecentSearches {
            recentSearches = Array(recentSearches.prefix(maxRecentSearches))
        }
        
        saveRecentSearches()
    }
    
    func clearRecentSearches() {
        recentSearches = []
        saveRecentSearches()
    }
    
    private func saveRecentSearches() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(recentSearches)
            UserDefaults.standard.set(data, forKey: recentSearchesKey)
        } catch {
            print("Error saving recent searches: \(error)")
        }
    }
    
    private func loadRecentSearches() {
        if let data = UserDefaults.standard.data(forKey: recentSearchesKey) {
            do {
                let decoder = JSONDecoder()
                recentSearches = try decoder.decode([String].self, from: data)
            } catch {
                print("Error loading recent searches: \(error)")
                recentSearches = []
            }
        }
    }
    
    // MARK: - Search
    
    func searchInteractions(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        let lowercasedQuery = query.lowercased()
        searchResults = interactionHistory.filter { interaction in
            interaction.drugA.lowercased().contains(lowercasedQuery) ||
            interaction.drugB.lowercased().contains(lowercasedQuery) ||
            interaction.description.lowercased().contains(lowercasedQuery)
        }
    }
    
    func clearSearchResults() {
        searchResults = []
    }
} 