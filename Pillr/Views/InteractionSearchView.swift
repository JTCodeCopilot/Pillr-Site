import SwiftUI

// Import UI components from separate files

// MARK: - Main Interaction Search View
struct InteractionSearchView: View {
    @ObservedObject private var openAIService = OpenAIService.shared
    @StateObject private var interactionStore = InteractionStore.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var drugA = ""
    @State private var drugB = ""
    @State private var searchResult: DrugInteraction?
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showingError = false
    @State private var showingAPIKeySheet = false
    @State private var showingFeatureSheet = false
    @State private var showingHistory = false
    @FocusState private var isDrugAFocused: Bool
    @FocusState private var isDrugBFocused: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                // Enhanced background with subtle gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "#404C42"),
                        Color(hex: "#3A443D")
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        // Enhanced Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Drug Interaction Checker")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: "#E8E8E0"))
                            
                            Text("Check for potential interactions between medications")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                        }
                        .padding(.top, 20)
                        
                        // Search Section
                        FormSection(title: "MEDICATIONS", icon: "pills.fill") {
                            VStack(spacing: 16) {
                                enhancedInputField(
                                    title: "First Medication",
                                    placeholder: "e.g., Aspirin",
                                    text: $drugA,
                                    iconName: "pill.circle.fill",
                                    isFocused: $isDrugAFocused
                                )
                                
                                enhancedInputField(
                                    title: "Second Medication",
                                    placeholder: "e.g., Warfarin",
                                    text: $drugB,
                                    iconName: "pill.circle.fill",
                                    isFocused: $isDrugBFocused
                                )
                                
                                // Search button
                                Button {
                                    HapticManager.shared.mediumImpact()
                                    searchInteraction()
                                } label: {
                                    HStack {
                                        if isLoading {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                                .tint(Color(hex: "#404C42"))
                                        } else {
                                            Image(systemName: "magnifyingglass.circle.fill")
                                                .font(.system(size: 18, weight: .semibold))
                                        }
                                        Text(isLoading ? "Checking..." : "Check Interactions")
                                            .font(.system(size: 18, weight: .bold, design: .rounded))
                                    }
                                    .foregroundColor(isButtonDisabled ? Color.white : Color(hex: "#404C42"))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(isButtonDisabled ? Color.gray.opacity(0.6) : Color(hex: "#C7C7BD"))
                                            .shadow(color: isButtonDisabled ? Color.clear : Color(hex: "#C7C7BD").opacity(0.3), radius: 8, x: 0, y: 4)
                                    )
                                }
                                .disabled(isButtonDisabled)
                                .buttonStyle(ScaleButtonStyle())
                                
                                // Quick action buttons
                                if !drugA.isEmpty || !drugB.isEmpty {
                                    HStack(spacing: 12) {
                                        Button("Clear") {
                                            drugA = ""
                                            drugB = ""
                                            searchResult = nil
                                        }
                                        .font(.caption.bold())
                                        .foregroundColor(Color(hex: "#C7C7BD"))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.black.opacity(0.2))
                                        .cornerRadius(8)
                                        
                                        Button("Swap") {
                                            let temp = drugA
                                            drugA = drugB
                                            drugB = temp
                                        }
                                        .font(.caption.bold())
                                        .foregroundColor(Color(hex: "#C7C7BD"))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.black.opacity(0.2))
                                        .cornerRadius(8)
                                        
                                        Spacer()
                                    }
                                }
                            }
                        }
                        
                        // Recent searches section
                        if !interactionStore.recentSearches.isEmpty && searchResult == nil {
                            FormSection(title: "RECENT SEARCHES", icon: "clock.fill") {
                                VStack(spacing: 8) {
                                    ForEach(interactionStore.recentSearches.prefix(5), id: \.self) { search in
                                        RecentSearchRow(search: search) {
                                            let components = search.components(separatedBy: " and ")
                                            if components.count == 2 {
                                                drugA = components[0]
                                                drugB = components[1]
                                            }
                                        } onRemove: {
                                            interactionStore.removeRecentSearch(search)
                                        }
                                    }
                                    
                                    if interactionStore.recentSearches.count > 5 {
                                        Button("View All Recent Searches") {
                                            showingHistory = true
                                        }
                                        .font(.caption.bold())
                                        .foregroundColor(Color.pillrAccent)
                                    }
                                }
                            }
                        }

                        // API key warning (Only show if not in premium mode and no key set)
                        if !openAIService.hasAPIKey() {
                            FormSection(title: "PREMIUM FEATURE", icon: "star.fill") {
                                VStack(spacing: 16) {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(Color(hex: "#FFB74D"))
                                            .font(.system(size: 20))
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Premium Required")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(Color(hex: "#E8E8E0"))
                                            
                                            Text("Enable Premium for AI-powered interaction checks")
                                                .font(.system(size: 14))
                                                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                                        }
                                        
                                        Spacer()
                                    }
                                    
                                    Button {
                                        HapticManager.shared.lightImpact()
                                        openAIService.enablePremiumMode()
                                        showingFeatureSheet = true
                                    } label: {
                                        HStack {
                                            Image(systemName: "star.circle.fill")
                                                .font(.system(size: 16, weight: .semibold))
                                            Text("Enable Premium")
                                                .font(.system(size: 16, weight: .semibold))
                                        }
                                        .foregroundColor(Color(hex: "#404C42"))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color(hex: "#FFB74D"))
                                                .shadow(color: Color(hex: "#FFB74D").opacity(0.3), radius: 4, x: 0, y: 2)
                                        )
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                }
                            }
                        }
                        
                        // Results display
                        if let interaction = searchResult {
                            FormSection(title: "INTERACTION RESULTS", icon: "checkmark.shield.fill") {
                                InteractionResultView(interaction: interaction)
                            }
                        }
                        
                        // Quick tips section
                        if searchResult == nil && !isLoading {
                            FormSection(title: "TIPS", icon: "lightbulb.fill") {
                                VStack(alignment: .leading, spacing: 12) {
                                    TipRow(
                                        icon: "text.cursor",
                                        title: "Be Specific",
                                        description: "Use exact medication names for best results"
                                    )
                                    
                                    TipRow(
                                        icon: "clock.arrow.circlepath",
                                        title: "Check Regularly",
                                        description: "Recheck when starting new medications"
                                    )
                                    
                                    TipRow(
                                        icon: "person.fill.checkmark",
                                        title: "Consult Your Doctor",
                                        description: "Always discuss interactions with healthcare providers"
                                    )
                                }
                            }
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                }
                .alert(isPresented: $showingError) {
                    Alert(
                        title: Text("Error"),
                        message: Text(errorMessage),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        HapticManager.shared.lightImpact()
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#C7C7BD"))
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack {
                        Button {
                            HapticManager.shared.lightImpact()
                            showingAPIKeySheet = true
                        } label: {
                            Image(systemName: "key.fill")
                                .foregroundColor(Color(hex: "#C7C7BD"))
                        }
                        
                        if !interactionStore.interactionHistory.isEmpty {
                            Button {
                                HapticManager.shared.lightImpact()
                                showingHistory = true
                            } label: {
                                Image(systemName: "clock.fill")
                                    .foregroundColor(Color(hex: "#C7C7BD"))
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAPIKeySheet) {
                APIKeyView()
                    .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $showingFeatureSheet) {
                FeatureSheetView(isPresented: $showingFeatureSheet)
            }
            .sheet(isPresented: $showingHistory) {
                InteractionHistoryView()
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private func FormSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(Color(hex: "#C7C7BD"))
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                    .tracking(0.5)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                content()
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(hex: "#C7C7BD").opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
    
    @ViewBuilder
    private func enhancedInputField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        iconName: String? = nil,
        isFocused: FocusState<Bool>.Binding
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let iconName = iconName {
                    Image(systemName: iconName)
                        .foregroundColor(Color(hex: "#C7C7BD"))
                        .font(.system(size: 16, weight: .medium))
                }
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#E8E8E0"))
            }
            
            TextField(placeholder, text: text)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(hex: "#E8E8E0"))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    isFocused.wrappedValue ? Color.pillrAccent.opacity(0.6) : Color(hex: "#C7C7BD").opacity(0.3),
                                    lineWidth: isFocused.wrappedValue ? 2 : 1
                                )
                        )
                )
                .focused(isFocused)
                .submitLabel(.next)
                .onSubmit {
                    if title.contains("First") {
                        isDrugBFocused = true
                    } else {
                        isDrugBFocused = false
                        if !isButtonDisabled {
                            searchInteraction()
                        }
                    }
                }
        }
    }
    
    private var isButtonDisabled: Bool {
        return drugA.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || 
               drugB.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || 
               isLoading
    }
    
    private func searchInteraction() {
        let cleanDrugA = drugA.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDrugB = drugB.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanDrugA.isEmpty && !cleanDrugB.isEmpty else { return }
        
        // Check if drugs are the same
        if cleanDrugA.lowercased() == cleanDrugB.lowercased() {
            errorMessage = "Please enter two different medications to check for interactions."
            showingError = true
            return
        }
        
        isLoading = true
        errorMessage = ""
        searchResult = nil
        
        // Dismiss keyboard
        isDrugAFocused = false
        isDrugBFocused = false
        
        Task {
            do {
                let result = try await openAIService.checkDrugInteractions(drugA: cleanDrugA, drugB: cleanDrugB)
                DispatchQueue.main.async {
                    searchResult = result
                    isLoading = false
                    
                    // Save to recent searches
                    let searchTerm = "\(cleanDrugA) and \(cleanDrugB)"
                    interactionStore.addRecentSearch(searchTerm)
                }
            } catch {
                DispatchQueue.main.async {
                    let errorMessage = error.localizedDescription
                    self.errorMessage = errorMessage
                    showingError = true
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct RecentSearchRow: View {
    let search: String
    let onTap: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onTap) {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.6))
                        .font(.caption)
                    
                    Text(search)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "#E8E8E0"))
                    
                    Spacer()
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.4))
                    .font(.caption)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 4)
    }
}

struct TipRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(Color.pillrAccent.opacity(0.8))
                .font(.system(size: 16, weight: .medium))
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#E8E8E0"))
                
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
            }
            
            Spacer()
        }
    }
}



// MARK: - Previews
struct InteractionSearchView_Previews: PreviewProvider {
    static var previews: some View {
        InteractionSearchView()
            .environmentObject(OpenAIService.shared)
            .preferredColorScheme(.dark)
    }
}

// History view and related components removed as per requirements

// InteractionHeaderView moved to UIComponents.swift

// PremiumBadgeView moved to UIComponents.swift

// InteractionSearchInputView moved to UIComponents.swift

// APIKeyWarningView moved to UIComponents.swift

// LoadingView moved to UIComponents.swift

// InteractionResultView moved to UIComponents.swift 