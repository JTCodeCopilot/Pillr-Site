import SwiftUI

struct InteractionResultsSheetView: View {
    @Binding var isPresented: Bool
    let interactions: [DrugInteraction]
    let error: String?
    
    @StateObject private var interactionStore = InteractionStore.shared
    @State private var selectedSeverityFilter: DrugInteraction.InteractionSeverity? = nil
    @State private var showingShareSheet = false
    @State private var shareText = ""
    @State private var shareItems: [Any] = []

    var filteredInteractions: [DrugInteraction] {
        guard let filter = selectedSeverityFilter else { return interactions }
        return interactions.filter { $0.severity == filter }
    }
    
    var severityCounts: [DrugInteraction.InteractionSeverity: Int] {
        var counts: [DrugInteraction.InteractionSeverity: Int] = [:]
        for interaction in interactions {
            counts[interaction.severity, default: 0] += 1
        }
        return counts
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#404C42").ignoresSafeArea()

                if let error = error {
                    errorView(error: error)
                } else if interactions.isEmpty {
                    noInteractionsView
                } else {
                    interactionsView
                }
            }
            .navigationTitle("Interaction Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !interactions.isEmpty {
                        shareButton
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(activityItems: shareItems)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            for interaction in interactions {
                interactionStore.saveInteraction(interaction)
            }
        }
    }
    
    // MARK: - Subviews
    
    private func errorView(error: String) -> some View {
        ErrorStateView(
            title: "Error Checking Interactions",
            message: error,
            actionTitle: "Try Again",
            action: {
                isPresented = false
            },
            icon: "exclamationmark.triangle.fill"
        )
    }
    
    private var noInteractionsView: some View {
        EmptyStateView(
            title: "No Interactions Found",
            message: "Great news! No significant interactions were detected between your selected medications. Always consult your healthcare provider for personalized advice.",
            actionTitle: nil,
            action: nil,
            icon: "checkmark.shield.fill"
        )
    }
    
    private var interactionsView: some View {
        VStack(spacing: 0) {
            // Summary header
            summaryHeader
            
            // Filter section
            if severityCounts.count > 1 {
                filterSection
            }
            
            // Interactions list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(filteredInteractions) { interaction in
                        InteractionRowView(interaction: interaction)
                    }
                    
                    // Disclaimer
                    disclaimerView
                }
                .padding()
            }
        }
    }
    
    private var summaryHeader: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(interactions.count) Interaction\(interactions.count == 1 ? "" : "s") Found")
                        .font(.title2).bold()
                        .foregroundColor(Color(hex: "#C7C7BD"))
                    
                    if let highestSeverity = interactions.map(\.severity).max(by: { severity1, severity2 in
                        let order: [DrugInteraction.InteractionSeverity] = [.unknown, .minor, .moderate, .major, .contraindicated]
                        return (order.firstIndex(of: severity1) ?? 0) < (order.firstIndex(of: severity2) ?? 0)
                    }) {
                        Text("Highest severity: \(highestSeverity.rawValue)")
                            .font(.subheadline)
                            .foregroundColor(Color(hex: highestSeverity.color))
                    }
                }
                
                Spacer()
                
                // Quick severity overview
                HStack(spacing: 8) {
                    ForEach(DrugInteraction.InteractionSeverity.allCases, id: \.self) { severity in
                        if let count = severityCounts[severity], count > 0 {
                            VStack(spacing: 2) {
                                Text("\(count)")
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                                
                                Circle()
                                    .fill(Color(hex: severity.color))
                                    .frame(width: 8, height: 8)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.2))
    }
    
    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                FilterChip(
                    title: "All (\(interactions.count))",
                    isSelected: selectedSeverityFilter == nil,
                    color: Color(hex: "#C7C7BD")
                ) {
                    selectedSeverityFilter = nil
                }
                
                ForEach(DrugInteraction.InteractionSeverity.allCases, id: \.self) { severity in
                    if let count = severityCounts[severity], count > 0 {
                        FilterChip(
                            title: "\(severity.displayName) (\(count))",
                            isSelected: selectedSeverityFilter == severity,
                            color: Color(hex: severity.color)
                        ) {
                            selectedSeverityFilter = selectedSeverityFilter == severity ? nil : severity
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.1))
    }
    
    private var disclaimerView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "hourglass")
                    .foregroundColor(Color.pillrAccent.opacity(0.8))
                Text("Powered by AI")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.pillrAccent.opacity(0.8))
            }
            
            Text("This information is generated by an AI model and is not a substitute for professional medical advice. Always consult your doctor or pharmacist for any health concerns or before making any decisions related to your health or treatment.")
                .font(.caption2)
                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.top, 2)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color.black.opacity(0.2))
        .cornerRadius(12)
        .padding(.top, 16)
    }
    
    private var shareButton: some View {
        Button {
            shareText = generateShareText()
            shareItems = [shareText]
            showingShareSheet = true
        } label: {
            Image(systemName: "square.and.arrow.up")
                .foregroundColor(Color.pillrAccent)
        }
    }
    
    private func generateShareText() -> String {
        var text = "Drug Interaction Report\n"
        text += "Generated on \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))\n\n"
        
        text += "Summary: \(interactions.count) interaction\(interactions.count == 1 ? "" : "s") found\n\n"
        
        for interaction in interactions {
            text += "• \(interaction.drugA) + \(interaction.drugB)\n"
            text += "  Severity: \(interaction.severity.displayName)\n"
            text += "  \(interaction.description)\n"
            text += "  Action: \(interaction.recommendedAction)\n\n"
        }
        
        text += "⚠️ This information is AI-generated and should not replace professional medical advice."
        
        return text
    }
}

// MARK: - Supporting Views

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(isSelected ? .black : color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? color : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(color, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(Color(hex: "#0A0F0C"))
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.pillrAccent)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct InteractionRowView: View {
    let interaction: DrugInteraction

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with drug names and severity
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(interaction.drugA) + \(interaction.drugB)")
                        .font(.headline)
                        .foregroundColor(Color(hex: "#E0E0E0"))
                    
                    Text("Checked \(timeAgoString(from: interaction.timestamp))")
                        .font(.caption2)
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.6))
                }
                
                Spacer()
                
                // Severity badge
                Text(interaction.severity.displayName)
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(hex: interaction.severity.color).opacity(0.9))
                    .foregroundColor(.black)
                    .cornerRadius(8)
            }

            // Description
            Text(interaction.description)
                .font(.subheadline)
                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
            
            // Recommendation with icon
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
                        .fixedSize(horizontal: false, vertical: true)
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
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct InteractionResultsSheetView_Previews: PreviewProvider {
    static var previews: some View {
        // Preview with interactions
        InteractionResultsSheetView(
            isPresented: .constant(true),
            interactions: [
                DrugInteraction(drugA: "Warfarin", drugB: "Aspirin", severity: .major, description: "Increased risk of bleeding due to additive anticoagulant effects.", recommendedAction: "Consult doctor immediately before combining these medications."),
                DrugInteraction(drugA: "Lisinopril", drugB: "Ibuprofen", severity: .moderate, description: "May reduce effectiveness of Lisinopril and increase risk of kidney damage.", recommendedAction: "Monitor blood pressure and kidney function; discuss with doctor."),
                DrugInteraction(drugA: "Metformin", drugB: "Alcohol", severity: .minor, description: "May increase risk of lactic acidosis in rare cases.", recommendedAction: "Limit alcohol consumption and monitor for symptoms.")
            ],
            error: nil
        )
        .previewDisplayName("With Multiple Interactions")

        // Preview with no interactions
        InteractionResultsSheetView(
            isPresented: .constant(true),
            interactions: [],
            error: nil
        )
        .previewDisplayName("No Interactions")

        // Preview with error
        InteractionResultsSheetView(
            isPresented: .constant(true),
            interactions: [],
            error: "Failed to connect to the server. Please check your internet connection and try again."
        )
        .previewDisplayName("With Error")
    }
} 
