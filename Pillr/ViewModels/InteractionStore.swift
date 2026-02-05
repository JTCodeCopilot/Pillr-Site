import SwiftUI
import Combine

class InteractionStore: ObservableObject {
    @Published var interactionHistory: [DrugInteraction] = []
    @Published var searchResults: [DrugInteraction] = []
    @Published var recentSearches: [String] = []
    @Published var isSearching = false
    @Published var selectedSeverityFilter: DrugInteraction.InteractionSeverity? = nil
    @Published var sortOrder: SortOrder = .dateDescending
    
    // Local device storage keys - data persists until app is completely uninstalled
    private let historyKey = "interactionHistoryData"
    private let recentSearchesKey = "recentSearchesData"
    private let deletedInteractionIDsKey = "deletedInteractionIDs"
    private let maxRecentSearches = 10
    private let maxHistoryItems = 100
    private let cloudSync: CloudKitInteractionSyncProtocol
    private var cloudSyncPreferenceCancellable: AnyCancellable?
    private var lastCloudSyncPreferenceState: Bool = false
    private var deletedInteractionIDs: Set<UUID> = []
    private let isPreviewMode: Bool
    
    // Singleton instance
    static let shared = InteractionStore()
    
    enum SortOrder: String, CaseIterable {
        case dateDescending = "Newest First"
        case dateAscending = "Oldest First"
        case severityDescending = "Most Severe First"
        case alphabetical = "Alphabetical"
        
        var systemImage: String {
            switch self {
            case .dateDescending: return "calendar.badge.minus"
            case .dateAscending: return "calendar.badge.plus"
            case .severityDescending: return "exclamationmark.triangle.fill"
            case .alphabetical: return "textformat.abc"
            }
        }
    }
    
    private var shouldUseCloudSync: Bool {
        !isPreviewMode && !isRunningTests && UserSettings.shared.shouldUseCloudSync
    }

    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private init(
        isPreview: Bool = false,
        cloudSync: CloudKitInteractionSyncProtocol = CloudKitMedicationSync.shared
    ) {
        self.isPreviewMode = isPreview
        self.cloudSync = cloudSync
        if !isPreview {
            if let stored = UserDefaults.standard.stringArray(forKey: deletedInteractionIDsKey) {
                deletedInteractionIDs = Set(stored.compactMap { UUID(uuidString: $0) })
            }
        }
        loadInteractionHistory()
        loadRecentSearches()
        lastCloudSyncPreferenceState = shouldUseCloudSync
        if shouldUseCloudSync {
            fetchCloudInteractions()
        }
        observeCloudSyncPreference()
    }
    
    // MARK: - Computed Properties
    
    var filteredHistory: [DrugInteraction] {
        var filtered = interactionHistory
        
        // Apply severity filter
        if let severityFilter = selectedSeverityFilter {
            filtered = filtered.filter { $0.severity == severityFilter }
        }
        
        // Apply sorting
        switch sortOrder {
        case .dateDescending:
            filtered.sort { $0.timestamp > $1.timestamp }
        case .dateAscending:
            filtered.sort { $0.timestamp < $1.timestamp }
        case .severityDescending:
            filtered.sort { interaction1, interaction2 in
                let severityOrder: [DrugInteraction.InteractionSeverity] = [
                    .contraindicated, .major, .moderate, .minor, .unknown
                ]
                
                guard let index1 = severityOrder.firstIndex(of: interaction1.severity),
                      let index2 = severityOrder.firstIndex(of: interaction2.severity) else {
                    return false
                }
                
                if index1 != index2 {
                    return index1 < index2
                }
                
                // Secondary sort by date if severity is the same
                return interaction1.timestamp > interaction2.timestamp
            }
        case .alphabetical:
            filtered.sort { interaction1, interaction2 in
                let name1 = "\(interaction1.drugA) + \(interaction1.drugB)"
                let name2 = "\(interaction2.drugA) + \(interaction2.drugB)"
                return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
            }
        }
        
        return filtered
    }
    
    var severityCounts: [DrugInteraction.InteractionSeverity: Int] {
        var counts: [DrugInteraction.InteractionSeverity: Int] = [:]
        for interaction in interactionHistory {
            counts[interaction.severity, default: 0] += 1
        }
        return counts
    }
    
    var hasHighSeverityInteractions: Bool {
        return interactionHistory.contains { interaction in
            interaction.severity == .major || interaction.severity == .contraindicated
        }
    }
    
    // MARK: - Persistence
    
    func saveInteraction(_ interaction: DrugInteraction) {
        var interactionToSync = interaction
        // Check if this interaction already exists (same drug pair)
        let existingIndex = interactionHistory.firstIndex { existing in
            let existingPair = Set([existing.drugA.lowercased(), existing.drugB.lowercased()])
            let newPair = Set([interaction.drugA.lowercased(), interaction.drugB.lowercased()])
            return existingPair == newPair
        }
        
        if let index = existingIndex {
            // Update existing interaction with newer timestamp
            var updated = interaction
            updated.id = interactionHistory[index].id
            interactionHistory[index] = updated
            deletedInteractionIDs.remove(updated.id)
            interactionToSync = updated
        } else {
            // Add new interaction to the top
            interactionHistory.insert(interaction, at: 0)
            deletedInteractionIDs.remove(interaction.id)
        }
        
        // Limit history size
        if interactionHistory.count > maxHistoryItems {
            interactionHistory = Array(interactionHistory.prefix(maxHistoryItems))
        }
        
        saveInteractionHistory()
        persistDeletedInteractionIDs()
        syncInteractionWithCloud(interactionToSync)
        
        // Save the search term
        let searchTerm = "\(interaction.drugA) and \(interaction.drugB)"
        addRecentSearch(searchTerm)
    }
    
    func saveMultipleInteractions(_ interactions: [DrugInteraction]) {
        for interaction in interactions {
            saveInteraction(interaction)
        }
    }
    
    func removeInteraction(_ interaction: DrugInteraction) {
        interactionHistory.removeAll { $0.id == interaction.id }
        saveInteractionHistory()
        deletedInteractionIDs.insert(interaction.id)
        persistDeletedInteractionIDs()
        syncDeleteInteraction(interaction)
    }
    
    func clearHistory() {
        let ids = interactionHistory.map { $0.id }
        interactionHistory.removeAll()
        saveInteractionHistory()
        deletedInteractionIDs.formUnion(ids)
        persistDeletedInteractionIDs()
        if shouldUseCloudSync {
            for id in ids {
                let tombstone = DrugInteraction(
                    id: id,
                    drugA: "Deleted Interaction",
                    drugB: "",
                    severity: .unknown,
                    description: "Deleted Interaction",
                    recommendedAction: "",
                    timestamp: Date()
                )
                syncDeleteInteraction(tombstone)
            }
        }
    }
    
    private func saveInteractionHistory() {
        do {
            // Save interaction history locally on device only
            // This data persists until the app is completely uninstalled
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

    private func persistDeletedInteractionIDs() {
        let ids = deletedInteractionIDs.map { $0.uuidString }
        UserDefaults.standard.set(ids, forKey: deletedInteractionIDsKey)
    }

    private func observeCloudSyncPreference() {
        cloudSyncPreferenceCancellable = UserSettings.shared.$shouldUseCloudSync
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleCloudSyncPreferenceChange()
            }
    }

    private func handleCloudSyncPreferenceChange() {
        let enabled = shouldUseCloudSync
        if enabled && !lastCloudSyncPreferenceState {
            cloudSync.ensureSubscriptions()
            performInitialCloudSync()
        }
        lastCloudSyncPreferenceState = enabled
    }

    private func fetchCloudInteractions() {
        guard shouldUseCloudSync else { return }
        cloudSync.fetchInteractions { [weak self] result in
            guard let self else { return }
            switch result {
            case let .success(records):
                self.mergeCloudInteractions(records)
            case let .failure(error):
                print("CloudKit interaction fetch failed: \(error)")
            }
        }
    }

    private func performInitialCloudSync() {
        guard shouldUseCloudSync else { return }
        cloudSync.fetchInteractions { [weak self] result in
            guard let self else { return }
            switch result {
            case let .success(records):
                self.mergeCloudInteractions(records)
                self.pushLocalInteractionsToCloud(remoteRecords: records)
                self.syncDeletedInteractionsIfNeeded(remoteRecords: records)
            case let .failure(error):
                print("CloudKit interaction fetch failed: \(error)")
            }
        }
    }

    private func syncInteractionWithCloud(_ interaction: DrugInteraction) {
        guard shouldUseCloudSync else { return }
        cloudSync.save(interaction: interaction) { result in
            if case let .failure(error) = result {
                print("CloudKit interaction save failed: \(error)")
            }
        }
    }

    private func syncDeleteInteraction(_ interaction: DrugInteraction) {
        guard shouldUseCloudSync else { return }
        cloudSync.markInteractionDeleted(interaction) { result in
            if case let .failure(error) = result {
                print("CloudKit interaction delete failed: \(error)")
            }
        }
    }

    private func pushLocalInteractionsToCloud(remoteRecords: [CloudInteractionRecord]) {
        guard shouldUseCloudSync else { return }
        let remoteByID = Dictionary(uniqueKeysWithValues: remoteRecords.map { ($0.interaction.id, $0) })
        for interaction in interactionHistory {
            if let remote = remoteByID[interaction.id] {
                let remoteUpdatedAt = remote.updatedAt ?? remote.interaction.timestamp
                if interaction.timestamp <= remoteUpdatedAt {
                    continue
                }
            }
            syncInteractionWithCloud(interaction)
        }
    }

    private func syncDeletedInteractionsIfNeeded(remoteRecords: [CloudInteractionRecord]) {
        guard shouldUseCloudSync else { return }
        let remoteIDs = Set(remoteRecords.map { $0.interaction.id })
        let missingDeletedIDs = deletedInteractionIDs.subtracting(remoteIDs)
        for id in missingDeletedIDs {
            let tombstone = DrugInteraction(
                id: id,
                drugA: "Deleted Interaction",
                drugB: "",
                severity: .unknown,
                description: "Deleted Interaction",
                recommendedAction: "",
                timestamp: Date()
            )
            syncDeleteInteraction(tombstone)
        }
    }

    private func mergeCloudInteractions(_ remote: [CloudInteractionRecord]) {
        guard !remote.isEmpty else { return }
        DispatchQueue.main.async {
            var updated = self.interactionHistory
            var changed = false

            for record in remote {
                let interaction = record.interaction
                if record.isDeleted {
                    if let index = updated.firstIndex(where: { $0.id == interaction.id }) {
                        updated.remove(at: index)
                        changed = true
                    }
                    self.deletedInteractionIDs.insert(interaction.id)
                    continue
                }

                if let index = updated.firstIndex(where: { $0.id == interaction.id }) {
                    let remoteUpdatedAt = record.updatedAt ?? interaction.timestamp
                    if remoteUpdatedAt > updated[index].timestamp {
                        updated[index] = interaction
                        changed = true
                    }
                } else {
                    updated.insert(interaction, at: 0)
                    changed = true
                }
            }

            if updated.count > self.maxHistoryItems {
                updated = Array(updated.prefix(self.maxHistoryItems))
                changed = true
            }

            if changed {
                self.interactionHistory = updated
                self.saveInteractionHistory()
                self.persistDeletedInteractionIDs()
            }
        }
    }
    
    // MARK: - Recent Searches
    
    func addRecentSearch(_ search: String) {
        let trimmedSearch = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearch.isEmpty else { return }
        
        // Remove if already exists to prevent duplicates
        recentSearches.removeAll { $0.lowercased() == trimmedSearch.lowercased() }
        
        // Add to the top
        recentSearches.insert(trimmedSearch, at: 0)
        
        // Limit to max number of recent searches
        if recentSearches.count > maxRecentSearches {
            recentSearches = Array(recentSearches.prefix(maxRecentSearches))
        }
        
        saveRecentSearches()
    }
    
    func removeRecentSearch(_ search: String) {
        recentSearches.removeAll { $0 == search }
        saveRecentSearches()
    }
    
    func clearRecentSearches() {
        recentSearches = []
        saveRecentSearches()
    }
    
    private func saveRecentSearches() {
        do {
            // Save recent searches locally on device only
            // This data persists until the app is completely uninstalled
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
    
    // MARK: - Search and Filtering
    
    func searchInteractions(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        let lowercasedQuery = query.lowercased()
        searchResults = interactionHistory.filter { interaction in
            interaction.drugA.lowercased().contains(lowercasedQuery) ||
            interaction.drugB.lowercased().contains(lowercasedQuery) ||
            interaction.description.lowercased().contains(lowercasedQuery) ||
            interaction.recommendedAction.lowercased().contains(lowercasedQuery) ||
            interaction.severity.displayName.lowercased().contains(lowercasedQuery)
        }
    }
    
    func filterBySeverity(_ severity: DrugInteraction.InteractionSeverity?) {
        selectedSeverityFilter = severity
    }
    
    func setSortOrder(_ order: SortOrder) {
        sortOrder = order
    }
    
    func clearSearchResults() {
        searchResults = []
    }
    
    // MARK: - Analytics and Insights
    
    func getInteractionsForDrug(_ drugName: String) -> [DrugInteraction] {
        let lowercasedDrug = drugName.lowercased()
        return interactionHistory.filter { interaction in
            interaction.drugA.lowercased() == lowercasedDrug ||
            interaction.drugB.lowercased() == lowercasedDrug
        }
    }
    
    func getMostCommonInteractions(limit: Int = 5) -> [DrugInteraction] {
        // Group interactions by drug pair and count occurrences
        var pairCounts: [String: (interaction: DrugInteraction, count: Int)] = [:]
        
        for interaction in interactionHistory {
            let pairKey = Set([interaction.drugA.lowercased(), interaction.drugB.lowercased()])
                .sorted()
                .joined(separator: "_")
            
            if let existing = pairCounts[pairKey] {
                pairCounts[pairKey] = (interaction, existing.count + 1)
            } else {
                pairCounts[pairKey] = (interaction, 1)
            }
        }
        
        return pairCounts.values
            .sorted { $0.count > $1.count }
            .prefix(limit)
            .map { $0.interaction }
    }
    
    func getRecentHighSeverityInteractions(days: Int = 7) -> [DrugInteraction] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        return interactionHistory.filter { interaction in
            interaction.timestamp >= cutoffDate &&
            (interaction.severity == .major || interaction.severity == .contraindicated)
        }
    }
    
    // MARK: - Export and Sharing
    
    func exportInteractionsAsText() -> String {
        var text = "Drug Interaction History\n"
        text += "Generated on \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))\n\n"
        
        for interaction in filteredHistory {
            text += "Interaction: \(interaction.drugA) + \(interaction.drugB)\n"
            text += "Severity: \(interaction.severity.displayName)\n"
            text += "Description: \(interaction.description)\n"
            text += "Recommendation: \(interaction.recommendedAction)\n"
            text += "Date: \(DateFormatter.localizedString(from: interaction.timestamp, dateStyle: .medium, timeStyle: .short))\n"
            text += "\n---\n\n"
        }
        
        text += "This information is generated by AI and should not replace professional medical advice."
        
        return text
    }
} 
