import SwiftUI

struct InteractionHistoryView: View {
    @StateObject private var interactionStore = InteractionStore.shared
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var showingShareSheet = false
    @State private var shareText = ""
    @State private var showingSortOptions = false
    @State private var showingClearAlert = false
    
    var filteredInteractions: [DrugInteraction] {
        let interactions = searchText.isEmpty ? interactionStore.filteredHistory : interactionStore.filteredHistory.filter { interaction in
            let searchLower = searchText.lowercased()
            return interaction.drugA.lowercased().contains(searchLower) ||
                   interaction.drugB.lowercased().contains(searchLower) ||
                   interaction.description.lowercased().contains(searchLower) ||
                   interaction.severity.rawValue.lowercased().contains(searchLower)
        }
        return interactions
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#404C42").ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search and filter header
                    headerSection
                    
                    if filteredInteractions.isEmpty {
                        emptyStateView
                    } else {
                        // Statistics section
                        if !searchText.isEmpty {
                            searchResultsHeader
                        } else {
                            statisticsSection
                        }
                        
                        // Interactions list
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredInteractions) { interaction in
                                    HistoryInteractionRow(interaction: interaction) {
                                        interactionStore.removeInteraction(interaction)
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Interaction History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color.pillrAccent)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if !interactionStore.interactionHistory.isEmpty {
                            Menu {
                                Button {
                                    shareText = interactionStore.exportInteractionsAsText()
                                    showingShareSheet = true
                                } label: {
                                    Label("Export History", systemImage: "square.and.arrow.up")
                                }
                                
                                Button(role: .destructive) {
                                    showingClearAlert = true
                                } label: {
                                    Label("Clear History", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .foregroundColor(Color.pillrAccent)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search interactions...")
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(activityItems: [shareText])
            }
            .alert("Clear History", isPresented: $showingClearAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    interactionStore.clearHistory()
                }
            } message: {
                Text("This will permanently delete all interaction history. This action cannot be undone.")
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Subviews
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Filter and sort controls
            HStack {
                // Severity filter
                Menu {
                    Button("All Severities") {
                        interactionStore.filterBySeverity(nil)
                    }
                    
                    ForEach(DrugInteraction.InteractionSeverity.allCases, id: \.self) { severity in
                        Button(severity.rawValue) {
                            interactionStore.filterBySeverity(severity)
                        }
                    }
                } label: {
                    HStack {
                        Text(interactionStore.selectedSeverityFilter?.rawValue ?? "All Severities")
                            .font(.caption.bold())
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundColor(Color(hex: "#E8E8E0"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(8)
                }
                
                Spacer()
                
                // Sort options
                Menu {
                    ForEach(InteractionStore.SortOrder.allCases, id: \.self) { order in
                        Button {
                            interactionStore.setSortOrder(order)
                        } label: {
                            Label(order.rawValue, systemImage: order.systemImage)
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: interactionStore.sortOrder.systemImage)
                            .font(.caption)
                        Text("Sort")
                            .font(.caption.bold())
                    }
                    .foregroundColor(Color(hex: "#E8E8E0"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.1))
    }
    
    private var searchResultsHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(filteredInteractions.count) result\(filteredInteractions.count == 1 ? "" : "s") for '\(searchText)'")
                    .font(.subheadline.bold())
                    .foregroundColor(Color(hex: "#C7C7BD"))
                
                Spacer()
                
                Button("Clear") {
                    searchText = ""
                }
                .font(.caption.bold())
                .foregroundColor(Color.pillrAccent)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.1))
    }
    
    private var statisticsSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(interactionStore.interactionHistory.count) Total Interactions")
                        .font(.headline.bold())
                        .foregroundColor(Color(hex: "#E8E8E0"))
                    
                    if interactionStore.hasHighSeverityInteractions {
                        Text("⚠️ High severity interactions found")
                            .font(.caption)
                            .foregroundColor(Color.orange)
                    }
                }
                
                Spacer()
                
                // Severity breakdown
                HStack(spacing: 8) {
                    ForEach(DrugInteraction.InteractionSeverity.allCases, id: \.self) { severity in
                        if let count = interactionStore.severityCounts[severity], count > 0 {
                            VStack(spacing: 2) {
                                Text("\(count)")
                                    .font(.caption2.bold())
                                    .foregroundColor(.white)
                                
                                Circle()
                                    .fill(Color(hex: severity.color))
                                    .frame(width: 6, height: 6)
                                
                                Text(severity.rawValue.prefix(3))
                                    .font(.caption2)
                                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color.black.opacity(0.15))
            .cornerRadius(12)
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: searchText.isEmpty ? "clock" : "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.6))
            
            Text(searchText.isEmpty ? "No Interaction History" : "No Results Found")
                .font(.title2.bold())
                .foregroundColor(Color(hex: "#C7C7BD"))
            
            Text(searchText.isEmpty ? 
                 "Your interaction checks will appear here for easy reference." :
                 "Try adjusting your search terms or filters.")
                .font(.body)
                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if searchText.isEmpty {
                Button("Check Interactions") {
                    dismiss()
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.pillrAccent)
                .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Supporting Views

struct HistoryInteractionRow: View {
    let interaction: DrugInteraction
    let onRemove: () -> Void
    @State private var showingDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(interaction.drugA) + \(interaction.drugB)")
                        .font(.headline)
                        .foregroundColor(Color(hex: "#E0E0E0"))
                    
                    HStack {
                        Text(timeAgoString(from: interaction.timestamp))
                            .font(.caption2)
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.6))
                        
                        Text("•")
                            .font(.caption2)
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.4))
                        
                        Text(interaction.severity.rawValue)
                            .font(.caption2.bold())
                            .foregroundColor(Color(hex: interaction.severity.color))
                    }
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button {
                        showingDetails.toggle()
                    } label: {
                        Image(systemName: showingDetails ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(Color(hex: "#C7C7BD"))
                    }
                    
                    Menu {
                        Button(role: .destructive) {
                            onRemove()
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.caption)
                            .foregroundColor(Color(hex: "#C7C7BD"))
                    }
                }
            }
            
            if showingDetails {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .background(Color(hex: "#C7C7BD").opacity(0.2))
                    
                    Text(interaction.description)
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))
                    
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(Color.yellow.opacity(0.8))
                            .font(.caption)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Recommendation")
                                .font(.caption.bold())
                                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                            
                            Text(interaction.recommendedAction)
                                .font(.footnote)
                                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.black.opacity(0.15))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: interaction.severity.color).opacity(0.3), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: showingDetails)
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct InteractionHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        InteractionHistoryView()
            .onAppear {
                // Add some sample data for preview
                let store = InteractionStore.shared
                store.saveInteraction(DrugInteraction(
                    drugA: "Warfarin",
                    drugB: "Aspirin",
                    severity: .major,
                    description: "Increased risk of bleeding.",
                    recommendedAction: "Consult doctor immediately."
                ))
                store.saveInteraction(DrugInteraction(
                    drugA: "Lisinopril",
                    drugB: "Ibuprofen",
                    severity: .moderate,
                    description: "May reduce effectiveness.",
                    recommendedAction: "Monitor blood pressure."
                ))
            }
    }
} 