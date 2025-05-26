import SwiftUI

struct MedicationInteractionSelectionSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: MedicationStore
    @State private var selectedMedicationIDs: Set<UUID> = []
    @State private var isCheckingInteractions = false
    @State private var foundInteractions: [DrugInteraction]? = nil
    @State private var interactionCheckError: String? = nil

    @State private var additionalMedications: [String] = []
    @State private var checkingProgress: Double = 0.0
    @State private var currentCheckingPair: String = ""
    @State private var hasCompletedCheck = false
    @State private var showingDetailedResults = false
    @State private var showingPremiumUpgrade = false
    
    var selectedMedications: [Medication] {
        store.activeMedications.filter { selectedMedicationIDs.contains($0.id) }
    }
    
    var totalSelectedCount: Int {
        selectedMedicationIDs.count + additionalMedications.count
    }
    
    var canCheckInteractions: Bool {
        totalSelectedCount >= 2
    }
    
    var allMedicationsToCheck: [String] {
        var medications: [String] = []
        medications.append(contentsOf: selectedMedications.map { $0.name })
        medications.append(contentsOf: additionalMedications)
        return medications
    }
    
    var totalInteractionPairs: Int {
        let count = allMedicationsToCheck.count
        return count * (count - 1) / 2
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#404C42").ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header section
                    headerSection
                    
                    // Main content
                    if hasCompletedCheck && !isCheckingInteractions {
                        // Results view
                        resultsSection
                    } else {
                        // Selection view
                        selectionSection
                    }
                    
                    // Bottom action section
                    bottomActionSection
                }
            }
            .navigationTitle(hasCompletedCheck ? "Interaction Results" : "Select Medications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(hasCompletedCheck ? "Back" : "Cancel") {
                        if hasCompletedCheck {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                hasCompletedCheck = false
                                foundInteractions = nil
                                interactionCheckError = nil
                            }
                        } else {
                            dismiss()
                        }
                    }
                    .foregroundColor(Color(hex: "#C7C7BD"))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !hasCompletedCheck {
                        Button(selectedMedicationIDs.count == store.activeMedications.count ? "Deselect All" : "Select All") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if selectedMedicationIDs.count == store.activeMedications.count {
                                    selectedMedicationIDs.removeAll()
                                } else {
                                    selectedMedicationIDs = Set(store.activeMedications.map { $0.id })
                                }
                            }
                        }
                        .foregroundColor(Color(hex: "#C7C7BD"))
                    } else {
                        Button("Done") {
                            dismiss()
                        }
                        .foregroundColor(Color(hex: "#C7C7BD"))
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            // Pre-select all medications by default
            selectedMedicationIDs = Set(store.activeMedications.map { $0.id })
        }
        .sheet(isPresented: $showingPremiumUpgrade) {
            PremiumUpgradeView()
        }
        .onChange(of: showingPremiumUpgrade) { isShowing in
            if !isShowing && OpenAIService.shared.isPremiumUser() {
                // User just returned from premium upgrade and now has premium
                // Reset the error state and go back to selection
                withAnimation(.easeInOut(duration: 0.3)) {
                    hasCompletedCheck = false
                    interactionCheckError = nil
                    foundInteractions = nil
                }
            }
        }

        .sheet(isPresented: $showingDetailedResults) {
            InteractionResultsSheetView(
                isPresented: $showingDetailedResults,
                interactions: foundInteractions ?? [],
                error: interactionCheckError
            )
        }
    }
    
    // MARK: - Subviews
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            if hasCompletedCheck {
                // Results header
                VStack(spacing: 8) {
                    if let interactions = foundInteractions {
                        if interactions.isEmpty {
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.shield.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(Color(hex: "#D9B382"))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("No Interactions Found")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(Color(hex: "#E8E8E0"))
                                    
                                    Text("Your selected medications appear safe together")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                                }
                                
                                Spacer()
                            }
                        } else {
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.orange)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(interactions.count) Interaction\(interactions.count == 1 ? "" : "s") Found")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(Color(hex: "#E8E8E0"))
                                    
                                    if let highestSeverity = interactions.map(\.severity).max(by: { severity1, severity2 in
                                        let order: [DrugInteraction.InteractionSeverity] = [.unknown, .minor, .moderate, .major, .contraindicated]
                                        return (order.firstIndex(of: severity1) ?? 0) < (order.firstIndex(of: severity2) ?? 0)
                                    }) {
                                        Text("Highest severity: \(highestSeverity.rawValue)")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(Color(hex: highestSeverity.color))
                                    }
                                }
                                
                                Spacer()
                            }
                        }
                    } else if let error = interactionCheckError {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.red)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Check Failed")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(Color(hex: "#E8E8E0"))
                                
                                Text(error)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                                    .lineLimit(2)
                            }
                            
                            Spacer()
                        }
                    }
                }
            } else {
                // Selection header
                VStack(spacing: 8) {
                    Text("Choose medications to check for interactions")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: "#C7C7BD"))
                        .multilineTextAlignment(.center)
                    
                    Text("\(totalSelectedCount) medication\(totalSelectedCount == 1 ? "" : "s") selected")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                }
                
                if !canCheckInteractions {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.orange)
                        Text("Select at least 2 medications to check interactions")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
    }
    
    private var selectionSection: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Search button for additional medications (disabled - AI functionality removed)
                Button(action: {
                    HapticManager.shared.lightImpact()
                    // Search functionality removed
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color(hex: "#D9B382"))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Search for Additional Medications")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(hex: "#E8E8E0"))
                            
                            Text("Add medications not in your active list")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(hex: "#C7C7BD"))
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(hex: "#3A4A5C").opacity(0.8),
                                        Color(hex: "#2F3A4A").opacity(0.8)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(hex: "#D9B382").opacity(0.3), lineWidth: 1)
                            )
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Additional medications section
                if !additionalMedications.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Additional Medications")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "#D9B382"))
                            .padding(.horizontal, 4)
                        
                        ForEach(Array(additionalMedications.enumerated()), id: \.offset) { index, medicationName in
                            AdditionalMedicationRow(
                                medicationName: medicationName,
                                onRemove: {
                                    HapticManager.shared.lightImpact()
                                    let _ = withAnimation(.easeInOut(duration: 0.3)) {
                                        additionalMedications.remove(at: index)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.top, 8)
                }
                
                // Active medications section
                if !store.activeMedications.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Active Medications")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "#C7C7BD"))
                            .padding(.horizontal, 4)
                        
                        ForEach(store.activeMedications) { medication in
                            MedicationSelectionRow(
                                medication: medication,
                                isSelected: selectedMedicationIDs.contains(medication.id)
                            ) {
                                toggleMedicationSelection(medication.id)
                            }
                        }
                    }
                    .padding(.top, additionalMedications.isEmpty ? 0 : 16)
                }
                
                // Selected medications summary and check button
                VStack(spacing: 16) {
                    // Selected medications summary
                    if !selectedMedicationIDs.isEmpty || !additionalMedications.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Selected Medications:")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "#E8E8E0"))
                            
                            FlowLayout(spacing: 8) {
                                // Active medications
                                ForEach(selectedMedications, id: \.id) { medication in
                                    Text(medication.name)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Color(hex: "#404C42"))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color(hex: "#C7C7BD"))
                                        .cornerRadius(6)
                                }
                                
                                // Additional medications
                                ForEach(additionalMedications, id: \.self) { medicationName in
                                    Text(medicationName)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Color(hex: "#2F3A4A"))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color(hex: "#D9B382"))
                                        .cornerRadius(6)
                                }
                            }
                        }
                    }
                    
                    // Check interactions button
                    Button {
                        HapticManager.shared.mediumImpact()
                        Task {
                            await checkSelectedMedicationInteractions()
                        }
                    } label: {
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "arrow.left.arrow.right.circle.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                Text(OpenAIService.shared.isPremiumUser() ? "Check Interactions" : "Check Interactions")
                                    .font(.system(size: 18, weight: .regular, design: .rounded))
                            }
                            
                            if OpenAIService.shared.isPremiumUser() {
                                Text("AI-Powered Analysis")
                                    .font(.system(size: 12, weight: .medium))
                                    .opacity(0.8)
                            } else {
                                Text("Upgrade for AI analysis")
                                    .font(.system(size: 12, weight: .medium))
                                    .opacity(0.8)
                            }
                        }
                        .foregroundColor(canCheckInteractions ? Color(hex: "#404C42") : Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(canCheckInteractions ? Color(hex: "#C7C7BD") : Color.gray.opacity(0.6))
                                .shadow(color: canCheckInteractions ? Color(hex: "#C7C7BD").opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)
                        )
                    }
                    .disabled(!canCheckInteractions)
                    .buttonStyle(ScaleButtonStyle())
                }
                .padding(.top, 24)
            }
            .padding()
        }
    }
    
    private var resultsSection: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if let interactions = foundInteractions {
                    if interactions.isEmpty {
                        // No interactions found
                        VStack(spacing: 20) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 60))
                                .foregroundColor(Color(hex: "#D9B382"))
                            
                            VStack(spacing: 8) {
                                Text("All Clear!")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(Color(hex: "#E8E8E0"))
                                
                                Text("No significant interactions were found among your selected medications.")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(hex: "#C7C7BD"))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            
                            VStack(spacing: 12) {
                                HStack {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundColor(Color.blue)
                                    Text("This doesn't mean interactions are impossible")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                                }
                                
                                Text("Always consult your healthcare provider about potential interactions, especially when starting new medications.")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                        .padding(.vertical, 40)
                    } else {
                        // Interactions found
                        VStack(spacing: 16) {
                            // Summary cards
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 12) {
                                SummaryCard(
                                    title: "Total Pairs",
                                    value: "\(totalInteractionPairs)",
                                    subtitle: "checked",
                                    color: Color(hex: "#D9B382")
                                )
                                
                                SummaryCard(
                                    title: "Interactions",
                                    value: "\(interactions.count)",
                                    subtitle: "found",
                                    color: .orange
                                )
                            }
                            .padding(.horizontal)
                            
                            // Interactions list
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Interaction Details")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(Color(hex: "#E8E8E0"))
                                    
                                    Spacer()
                                    
                                    Button("View All") {
                                        showingDetailedResults = true
                                    }
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color(hex: "#D9B382"))
                                }
                                .padding(.horizontal)
                                
                                ForEach(interactions.prefix(3)) { interaction in
                                    CompactInteractionRow(interaction: interaction)
                                        .padding(.horizontal)
                                }
                                
                                if interactions.count > 3 {
                                    Button("View \(interactions.count - 3) More Interactions") {
                                        showingDetailedResults = true
                                    }
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color(hex: "#D9B382"))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color(hex: "#D9B382").opacity(0.1))
                                    .cornerRadius(12)
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                } else if let error = interactionCheckError {
                    // Error state
                    VStack(spacing: 20) {
                        Image(systemName: error.contains("Premium") ? "crown.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(error.contains("Premium") ? Color(hex: "#FFD700") : .red)
                        
                        VStack(spacing: 8) {
                            Text(error.contains("Premium") ? "Premium Required" : "Check Failed")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Color(hex: "#E8E8E0"))
                            
                            Text(error)
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "#C7C7BD"))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        HStack(spacing: 16) {
                            if error.contains("Premium") {
                                Button("Upgrade to Premium") {
                                    showingPremiumUpgrade = true
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color(hex: "#D9B382"))
                                .cornerRadius(12)
                            }
                            
                            Button(error.contains("Premium") ? "Skip for Now" : "Try Again") {
                                if error.contains("Premium") {
                                    // Reset to selection view
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        hasCompletedCheck = false
                                        interactionCheckError = nil
                                        foundInteractions = nil
                                    }
                                } else {
                                    Task {
                                        await checkSelectedMedicationInteractions()
                                    }
                                }
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(error.contains("Premium") ? Color(hex: "#C7C7BD") : .white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(error.contains("Premium") ? Color.clear : Color(hex: "#D9B382"))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(hex: "#C7C7BD"), lineWidth: error.contains("Premium") ? 1 : 0)
                            )
                            .cornerRadius(12)
                        }
                    }
                    .padding(.vertical, 40)
                }
            }
            .padding(.vertical)
        }
    }
    
    private var bottomActionSection: some View {
        VStack(spacing: 16) {
            if isCheckingInteractions {
                // Progress section
                VStack(spacing: 12) {
                    HStack {
                        Text("Checking Interactions...")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "#E8E8E0"))
                        
                        Spacer()
                        
                        Text("\(Int(checkingProgress * 100))%")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "#C7C7BD"))
                    }
                    
                    ProgressView(value: checkingProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: Color(hex: "#D9B382")))
                        .scaleEffect(y: 2)
                    
                    if !currentCheckingPair.isEmpty {
                        Text("Checking: \(currentCheckingPair)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                    }
                }
                .padding()
                .background(Color.black.opacity(0.2))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            // Bottom padding
            Rectangle()
                .fill(Color.clear)
                .frame(height: 20)
        }
        .background(Color(hex: "#404C42"))
    }
    
    // MARK: - Helper Functions
    
    private func toggleMedicationSelection(_ medicationID: UUID) {
        HapticManager.shared.lightImpact()
        withAnimation(.easeInOut(duration: 0.2)) {
            if selectedMedicationIDs.contains(medicationID) {
                selectedMedicationIDs.remove(medicationID)
            } else {
                selectedMedicationIDs.insert(medicationID)
            }
        }
    }
    
    private func checkSelectedMedicationInteractions() async {
        guard canCheckInteractions else { return }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            isCheckingInteractions = true
            checkingProgress = 0.0
            currentCheckingPair = ""
            interactionCheckError = nil
            foundInteractions = nil
        }
        
        let medications = allMedicationsToCheck
        var interactionResults: [DrugInteraction] = []
        
        // Check if user has premium access
        guard OpenAIService.shared.isPremiumUser() else {
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    interactionCheckError = "Premium subscription required to access AI-powered interaction checking."
                    isCheckingInteractions = false
                    hasCompletedCheck = true
                }
            }
            return
        }
        
        await MainActor.run {
            currentCheckingPair = "Analyzing all medications..."
            checkingProgress = 0.5
        }
        
        do {
            // Use OpenAI to check all medication interactions at once
            interactionResults = try await OpenAIService.shared.checkMedicationInteractions(medications: medications)
            
            await MainActor.run {
                checkingProgress = 1.0
            }
            
        } catch {
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    if let openAIError = error as? OpenAIError {
                        interactionCheckError = openAIError.localizedDescription
                    } else {
                        interactionCheckError = "Failed to check interactions: \(error.localizedDescription)"
                    }
                    isCheckingInteractions = false
                    hasCompletedCheck = true
                }
            }
            return
        }
        
        // Sort interactions by severity (most severe first)
        interactionResults.sort { interaction1, interaction2 in
            let severityOrder: [DrugInteraction.InteractionSeverity] = [
                .contraindicated, .major, .moderate, .minor, .unknown
            ]
            
            guard let index1 = severityOrder.firstIndex(of: interaction1.severity),
                  let index2 = severityOrder.firstIndex(of: interaction2.severity) else {
                return false
            }
            
            return index1 < index2
        }
        
        // Save interactions to history
        for interaction in interactionResults {
            InteractionStore.shared.saveInteraction(interaction)
        }
        
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.5)) {
                self.foundInteractions = interactionResults
                isCheckingInteractions = false
                hasCompletedCheck = true
                checkingProgress = 1.0
                currentCheckingPair = ""
            }
        }
        
        // Haptic feedback based on results
        if interactionResults.isEmpty {
            HapticManager.shared.successNotification()
        } else {
            let hasHighSeverity = interactionResults.contains { interaction in
                interaction.severity == .major || interaction.severity == .contraindicated
            }
            if hasHighSeverity {
                HapticManager.shared.warningNotification()
            } else {
                HapticManager.shared.lightImpact()
            }
        }
    }
}

// MARK: - Supporting Views

struct SummaryCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
            
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)
            
            Text(subtitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.black.opacity(0.15))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

struct CompactInteractionRow: View {
    let interaction: DrugInteraction
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(interaction.drugA) + \(interaction.drugB)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "#E8E8E0"))
                
                Spacer()
                
                Text(interaction.severity.rawValue)
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: interaction.severity.color))
                    .foregroundColor(.black)
                    .cornerRadius(6)
            }
            
            Text(interaction.description)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))
                .lineLimit(2)
        }
        .padding(12)
        .background(Color.black.opacity(0.15))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(hex: interaction.severity.color).opacity(0.3), lineWidth: 1)
        )
    }
}

struct AdditionalMedicationRow: View {
    let medicationName: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Medication icon
                            ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "#D9B382").opacity(0.2))
                        .frame(width: 24, height: 24)
                    
                    Image(systemName: "pills.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "#D9B382"))
            }
            
            // Medication info
            VStack(alignment: .leading, spacing: 2) {
                Text(medicationName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color(hex: "#E8E8E0"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                                        Text("Additional medication")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "#D9B382"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Spacer()
            
            // Remove button
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "#FF6B6B"))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "#3A4A5C").opacity(0.7),
                            Color(hex: "#2F3A4A").opacity(0.7)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(hex: "#D9B382").opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct MedicationSelectionRow: View {
    let medication: Medication
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 16) {
                // Checkbox
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color(hex: "#C7C7BD") : Color(hex: "#C7C7BD").opacity(0.4), lineWidth: 2)
                        .frame(width: 24, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isSelected ? Color(hex: "#C7C7BD") : Color.clear)
                        )
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color(hex: "#404C42"))
                    }
                }
                
                // Medication info
                VStack(alignment: .leading, spacing: 4) {
                    Text(medication.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color(hex: "#E8E8E0"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("\(medication.dosage) - \(medication.frequency)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "#C7C7BD"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if let notes = medication.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(hex: "#525E55").opacity(isSelected ? 1.0 : 0.7),
                                Color(hex: "#4A554D").opacity(isSelected ? 1.0 : 0.7),
                                Color(hex: "#424D45").opacity(isSelected ? 1.0 : 0.7)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? Color(hex: "#C7C7BD").opacity(0.3) : Color.clear,
                                lineWidth: 1
                            )
                    )
            )
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Flow Layout for Selected Medications

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero
        
        init(in maxWidth: CGFloat, subviews: LayoutSubviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let subviewSize = subview.sizeThatFits(.unspecified)
                
                if currentX + subviewSize.width > maxWidth && currentX > 0 {
                    // Move to next line
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: currentX, y: currentY, width: subviewSize.width, height: subviewSize.height))
                
                currentX += subviewSize.width + spacing
                lineHeight = max(lineHeight, subviewSize.height)
            }
            
            size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
} 
