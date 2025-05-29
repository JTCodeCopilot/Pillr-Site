import SwiftUI
import PDFKit

struct InteractionHistoryView: View {
    @StateObject private var interactionStore = InteractionStore.shared
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var showingShareSheet = false
    @State private var shareText = ""
    @State private var showingSortOptions = false
    @State private var showingClearAlert = false
    @State private var showingSaveOptions = false
    @State private var saveFormat: SaveFormat = .text
    @State private var shareItems: [Any] = []
    
    enum SaveFormat: String, CaseIterable {
        case text = "Text File"
        case csv = "CSV File"
        
        var fileExtension: String {
            switch self {
            case .text: return "txt"
            case .csv: return "csv"
            }
        }
        
        var systemImage: String {
            switch self {
            case .text: return "doc.text"
            case .csv: return "tablecells"
            }
        }
    }
    
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
                // Background matching app theme
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
                            LazyVStack(spacing: 16) {
                                ForEach(filteredInteractions) { interaction in
                                    HistoryInteractionRow(interaction: interaction) {
                                        interactionStore.removeInteraction(interaction)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
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
                    .font(.system(size: 16, weight: .medium))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if !interactionStore.interactionHistory.isEmpty {
                            Menu {
                                // Save/Export options
                                Menu {
                                    ForEach(SaveFormat.allCases, id: \.self) { format in
                                        Button {
                                            saveInteractions(format: format)
                                        } label: {
                                            Label(format.rawValue, systemImage: format.systemImage)
                                        }
                                    }
                                } label: {
                                    Label("Save As...", systemImage: "square.and.arrow.down")
                                }
                                
                                Button {
                                    shareText = interactionStore.exportInteractionsAsText()
                                    shareItems = [shareText]
                                    showingShareSheet = true
                                } label: {
                                    Label("Share as Text", systemImage: "square.and.arrow.up")
                                }
                                
                                Divider()
                                
                                Button {
                                    saveToUserDefaults()
                                } label: {
                                    Label("Save to Device", systemImage: "internaldrive")
                                }
                                
                                Divider()
                                
                                Button(role: .destructive) {
                                    showingClearAlert = true
                                } label: {
                                    Label("Clear History", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .foregroundColor(Color.pillrAccent)
                                    .font(.system(size: 16))
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search interactions...")
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(activityItems: shareItems)
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
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 64))
                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.6))
            
            Text("No Interaction History")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Color(hex: "#E8E8E0"))
            
            Text("Your interaction checks will appear here for easy reference and tracking.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(Color(hex: "#C7C7BD"))
                .padding(.horizontal, 32)
            
            Button(action: {
                dismiss()
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Check Interactions")
                }
                .font(.headline)
                .foregroundColor(Color(hex: "#404C42"))
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color.pillrAccent)
                .cornerRadius(12)
            }
            .padding(.top, 16)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Filter and sort controls
            HStack(spacing: 12) {
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
                    HStack(spacing: 6) {
                        Text(interactionStore.selectedSeverityFilter?.rawValue ?? "All Severities")
                            .font(.system(size: 14, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(Color(hex: "#E8E8E0"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.15))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(hex: "#C7C7BD").opacity(0.1), lineWidth: 1)
                    )
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
                    HStack(spacing: 6) {
                        Image(systemName: interactionStore.sortOrder.systemImage)
                            .font(.system(size: 12))
                        Text("Sort")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(Color(hex: "#E8E8E0"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.15))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(hex: "#C7C7BD").opacity(0.1), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    private var searchResultsHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(filteredInteractions.count) result\(filteredInteractions.count == 1 ? "" : "s") for '\(searchText)'")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: "#E8E8E0"))
                
                Spacer()
                
                Button("Clear") {
                    searchText = ""
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.pillrAccent)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    private var statisticsSection: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(interactionStore.interactionHistory.count)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(hex: "#E8E8E0"))
                    
                    Text("Total Interactions")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "#C7C7BD"))
                    
                    if interactionStore.hasHighSeverityInteractions {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                            
                            Text("High severity found")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.orange)
                        }
                        .padding(.top, 4)
                    }
                }
                
                Spacer()
                
                // Severity breakdown
                VStack(alignment: .trailing, spacing: 8) {
                    Text("Severity Breakdown")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                    
                    VStack(spacing: 6) {
                        ForEach(DrugInteraction.InteractionSeverity.allCases, id: \.self) { severity in
                            if let count = interactionStore.severityCounts[severity], count > 0 {
                                HStack(spacing: 8) {
                                    Text(severity.rawValue)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Color(hex: "#C7C7BD"))
                                    
                                    Circle()
                                        .fill(Color(hex: severity.color))
                                        .frame(width: 8, height: 8)
                                    
                                    Text("\(count)")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(Color(hex: "#E8E8E0"))
                                }
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color.black.opacity(0.15))
        }
    }
    
    // MARK: - Save Functions
    
    private func saveInteractions(format: SaveFormat) {
        let fileName = "PillrInteractions_\(DateFormatter.fileNameFormatter.string(from: Date()))"
        
        switch format {
        case .text:
            let content = interactionStore.exportInteractionsAsText()
            shareItems = [createTextFile(content: content, fileName: "\(fileName).txt")]
            
        case .csv:
            let content = exportAsCSV()
            shareItems = [createTextFile(content: content, fileName: "\(fileName).csv")]
        }
        
        showingShareSheet = true
    }
    
    private func saveToUserDefaults() {
        // This function explicitly saves the current state to UserDefaults
        // The InteractionStore already does this automatically, but this provides user feedback
        
        // Force save all current interactions
        for interaction in filteredInteractions {
            interactionStore.saveInteraction(interaction)
        }
        
        // Show success feedback
        HapticManager.shared.mediumImpact()
        
        // You could add a toast notification here if you have one implemented
        print("Interactions saved to device successfully")
    }
    
    private func exportAsCSV() -> String {
        var csv = "Drug A,Drug B,Severity,Description,Recommendation,Date\n"
        
        for interaction in filteredInteractions {
            let dateString = DateFormatter.csvFormatter.string(from: interaction.timestamp)
            let row = [
                escapeCSVField(interaction.drugA),
                escapeCSVField(interaction.drugB),
                escapeCSVField(interaction.severity.rawValue),
                escapeCSVField(interaction.description),
                escapeCSVField(interaction.recommendedAction),
                escapeCSVField(dateString)
            ].joined(separator: ",")
            
            csv += row + "\n"
        }
        
        return csv
    }
    
    private func escapeCSVField(_ field: String) -> String {
        let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
    
    private func createTextFile(content: String, fileName: String) -> URL {
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(fileName)
        
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("Error creating file: \(error)")
        }
        
        return fileURL
    }
}

// MARK: - Supporting Views

struct HistoryInteractionRow: View {
    let interaction: DrugInteraction
    let onRemove: () -> Void
    @State private var showingDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main content
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(interaction.drugA) + \(interaction.drugB)")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color(hex: "#E8E8E0"))
                            .lineLimit(2)
                        
                        HStack(spacing: 8) {
                            Text(timeAgoString(from: interaction.timestamp))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                            
                            Circle()
                                .fill(Color(hex: "#C7C7BD").opacity(0.4))
                                .frame(width: 3, height: 3)
                            
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color(hex: interaction.severity.color))
                                    .frame(width: 6, height: 6)
                                
                                Text(interaction.severity.rawValue)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color(hex: interaction.severity.color))
                            }
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingDetails.toggle()
                            }
                        } label: {
                            Image(systemName: showingDetails ? "chevron.up" : "chevron.down")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "#C7C7BD"))
                                .frame(width: 24, height: 24)
                        }
                        
                        Menu {
                            Button(role: .destructive) {
                                onRemove()
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "#C7C7BD"))
                                .frame(width: 24, height: 24)
                        }
                    }
                }
            }
            .padding(20)
            
            // Expandable details
            if showingDetails {
                VStack(alignment: .leading, spacing: 16) {
                    Divider()
                        .background(Color(hex: "#C7C7BD").opacity(0.2))
                        .padding(.horizontal, 20)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Description")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "#E8E8E0"))
                        
                        Text(interaction.description)
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#C7C7BD"))
                            .lineLimit(nil)
                    }
                    .padding(.horizontal, 20)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow.opacity(0.8))
                                .font(.system(size: 14))
                            
                            Text("Recommendation")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "#E8E8E0"))
                        }
                        
                        Text(interaction.recommendedAction)
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#C7C7BD"))
                            .lineLimit(nil)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .gyroGlassCardStyle(cornerRadius: 16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: interaction.severity.color).opacity(0.3), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.3), value: showingDetails)
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

// MARK: - Export Data Structures

// MARK: - Date Formatters

extension DateFormatter {
    static let fileNameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()
    
    static let csvFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
} 
