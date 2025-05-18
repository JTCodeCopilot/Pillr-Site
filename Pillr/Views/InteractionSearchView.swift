import SwiftUI

// Import UI components from separate files

// MARK: - Main Interaction Search View
struct InteractionSearchView: View {
    @ObservedObject private var openAIService = OpenAIService.shared
    
    @State private var drugA = ""
    @State private var drugB = ""
    @State private var searchResult: DrugInteraction?
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showingError = false
    @State private var showingAPIKeySheet = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(hex: "#404C42")
                    .ignoresSafeArea(edges: [.top, .leading, .trailing, .bottom])
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Title and API key button section
                        InteractionHeaderView(
                            isPremiumMode: openAIService.isPremiumMode,
                            onApiKeyTap: { showingAPIKeySheet = true }
                        )
                        
                        // Search inputs
                        InteractionSearchInputView(
                            drugA: $drugA,
                            drugB: $drugB,
                            isButtonDisabled: isButtonDisabled,
                            onSearch: searchInteraction
                        )
                        
                        // API key warning (Only show if not in premium mode and no key set)
                        if !openAIService.hasAPIKey() {
                            APIKeyWarningView(
                                onEnablePremium: { openAIService.enablePremiumMode() }
                            )
                        }
                        
                        // Loading indicator
                        if isLoading {
                            LoadingView(message: "Checking interaction...")
                        }
                        
                        // Results display
                        if let interaction = searchResult {
                            InteractionResultView(interaction: interaction)
                        }
                        
                        Spacer(minLength: 50)
                    }
                }
                .alert(isPresented: $showingError) {
                    Alert(
                        title: Text("Error"),
                        message: Text(errorMessage),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }
            .navigationBarTitle("", displayMode: .inline)
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAPIKeySheet) {
                APIKeyView()
                    .preferredColorScheme(.dark)
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private var isButtonDisabled: Bool {
        return drugA.isEmpty || drugB.isEmpty || isLoading || !openAIService.hasAPIKey()
    }
    
    private func searchInteraction() {
        guard !drugA.isEmpty && !drugB.isEmpty else { return }
        guard openAIService.hasAPIKey() else {
            errorMessage = "Premium access required to use this feature"
            showingError = true
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                let result = try await openAIService.checkDrugInteractions(drugA: drugA, drugB: drugB)
                DispatchQueue.main.async {
                    searchResult = result
                    isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    let errorMessage = error.localizedDescription
                    self.errorMessage = "Error: \(errorMessage)"
                    showingError = true
                    isLoading = false
                }
            }
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