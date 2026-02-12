import SwiftUI
import PDFKit

struct InteractionHistoryView: View {
    let isModal: Bool
    @StateObject private var interactionStore = InteractionStore.shared
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: MedicationStore
    @EnvironmentObject var storeManager: StoreManager
    @State private var showingShareSheet = false
    @State private var shareText = ""
    @State private var showingClearAlert = false
    @State private var showingSaveOptions = false
    @State private var saveFormat: SaveFormat = .text
    @State private var shareItems: [Any] = []
    @State private var showingMedicationSelectionSheet = false
    
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
    
    init(isModal: Bool = true) {
        self.isModal = isModal
    }
    
    var filteredInteractions: [DrugInteraction] {
        interactionStore.filteredHistory
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#404C42").ignoresSafeArea()

                VStack(spacing: 0) {
                    headerView
                        .padding(.top, 16)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)

                    if filteredInteractions.isEmpty {
                        emptyStateView
                    } else {
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isModal {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Done") {
                            dismiss()
                        }
                        .foregroundColor(Color.pillrAccent)
                        .font(.system(size: 16, weight: .medium))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 10) {
                        Menu {
                            ForEach(SaveFormat.allCases, id: \.self) { format in
                                Button {
                                    saveInteractions(format: format)
                                } label: {
                                    Label(format.rawValue, systemImage: format.systemImage)
                                }
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color(hex: "#F5F7F4"))
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                        .frame(width: 46, height: 46)
                        .glassCircleBackground(diameter: 46, isSelected: false, opacity: 0.95)
                        .contentShape(Circle())
                        .disabled(filteredInteractions.isEmpty)
                        .opacity(filteredInteractions.isEmpty ? 0.5 : 1.0)
                        
                        Button {
                            showingClearAlert = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color(hex: "#F5F7F4"))
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                        .frame(width: 46, height: 46)
                        .glassCircleBackground(diameter: 46, isSelected: false, opacity: 0.95)
                        .contentShape(Circle())
                        .disabled(filteredInteractions.isEmpty)
                        .opacity(filteredInteractions.isEmpty ? 0.5 : 1.0)
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(activityItems: shareItems)
            }
            .sheet(isPresented: $showingMedicationSelectionSheet) {
                MedicationInteractionSelectionSheet()
                    .environmentObject(store)
                    .environmentObject(storeManager)
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
    }
    
    // MARK: - Subviews
    
    private var emptyStateView: some View {
        VStack {
            Spacer()

            VStack(spacing: 14) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 42))
                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                
                Text("No Interaction History")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(hex: "#E8E8E0"))
                
                Text("Your interaction checks will appear here for easy reference and tracking.")
                    .font(.system(size: 14))
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color(hex: "#C7C7BD"))
                    .padding(.horizontal, 24)
                
                Button(action: {
                    showingMedicationSelectionSheet = true
                }) {
                    Text("Check Interactions")
                        .font(.headline)
                        .foregroundColor(Color(hex: "#404C42"))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(Color.pillrAccent)
                        .cornerRadius(12)
                }
                .padding(.top, 10)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 18)

            Spacer()
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Interactions")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(Color(hex: "#F5F7F4"))
            
            Text("\(filteredInteractions.count) interaction\(filteredInteractions.count == 1 ? "" : "s")")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(hex: "#E0E7DC").opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                escapeCSVField(interaction.severity.displayName),
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
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(interaction.displayTitle)
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
                                
                                Text(interaction.severity.displayName)
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
            .padding(16)
            
            // Expandable details
            if showingDetails {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                        .background(Color(hex: "#C7C7BD").opacity(0.2))
                        .padding(.horizontal, 16)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "#E8E8E0"))
                        
                        Text(interaction.description)
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#C7C7BD"))
                            .lineLimit(nil)
                    }
                    .padding(.horizontal, 16)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recommendation")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "#E8E8E0"))
                        
                        Text(interaction.recommendedAction)
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#C7C7BD"))
                            .lineLimit(nil)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(hex: interaction.severity.color).opacity(0.25), lineWidth: 1)
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
            .environmentObject(MedicationStore.shared)
            .environmentObject(StoreManager.shared)
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
