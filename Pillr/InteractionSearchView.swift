import SwiftUI

struct InteractionSearchView: View {
    @ObservedObject private var openAIService = OpenAIService.shared
    @ObservedObject private var interactionStore = InteractionStore.shared
    
    @State private var drugA = ""
    @State private var drugB = ""
    @State private var searchResult: DrugInteraction?
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showingError = false
    @State private var showingAPIKeySheet = false
    @State private var showingHistory = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient.pillrBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Title and API key section
                        HStack {
                            Text("Medication Interactions")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Button(action: {
                                showingAPIKeySheet = true
                            }) {
                                HStack(spacing: 4) {
                                    if openAIService.isPremiumMode {
                                        Image(systemName: "star.fill")
                                            .foregroundColor(.yellow)
                                    } else {
                                        Image(systemName: "key.fill")
                                            .foregroundColor(.pillrAccent)
                                    }
                                }
                                .font(.system(size: 18))
                                .padding(10)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(openAIService.isPremiumMode ? Color.yellow.opacity(0.6) : Color.white.opacity(0.3), lineWidth: 1)
                                )
                            }
                            
                            Button(action: {
                                showingHistory = true
                            }) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 18))
                                    .foregroundColor(.pillrAccent)
                                    .padding(10)
                                    .background(Color.white.opacity(0.1))
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)
                        
                        // Premium badge if active
                        if openAIService.isPremiumMode {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(.yellow)
                                
                                Text("Premium Mode Active")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.black.opacity(0.2))
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.yellow.opacity(0.5), lineWidth: 1)
                            )
                        }
                        
                        // Search inputs
                        VStack(spacing: 16) {
                            TextField("First Medication", text: $drugA)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(10)
                                .foregroundColor(.white)
                                .accentColor(.pillrAccent)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                            
                            TextField("Second Medication", text: $drugB)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(10)
                                .foregroundColor(.white)
                                .accentColor(.pillrAccent)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                            
                            Button(action: searchInteraction) {
                                Text("Check Interaction")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.pillrAccent.opacity(0.8), Color.pillrAccent]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(10)
                            }
                            .disabled(drugA.isEmpty || drugB.isEmpty || isLoading || !openAIService.hasAPIKey())
                            .opacity((drugA.isEmpty || drugB.isEmpty || isLoading || !openAIService.hasAPIKey()) ? 0.6 : 1.0)
                        }
                        .padding(.horizontal)
                        
                        // API key warning (Only show if not in premium mode and no key set)
                        if !openAIService.hasAPIKey() {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.yellow)
                                    
                                    Text("API Key Required")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                }
                                
                                Text("To use the medication interaction checker, either enable Premium Mode or provide your own OpenAI API key.")
                                    .foregroundColor(.white.opacity(0.9))
                                
                                HStack {
                                    Button(action: {
                                        openAIService.enablePremiumMode()
                                    }) {
                                        HStack {
                                            Image(systemName: "star.fill")
                                                .font(.caption)
                                            Text("Enable Premium")
                                        }
                                        .fontWeight(.medium)
                                        .foregroundColor(.black)
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 16)
                                        .background(Color.yellow)
                                        .cornerRadius(8)
                                    }
                                    
                                    Button(action: {
                                        showingAPIKeySheet = true
                                    }) {
                                        Text("Set API Key")
                                            .fontWeight(.medium)
                                            .foregroundColor(.white)
                                            .padding(.vertical, 10)
                                            .padding(.horizontal, 16)
                                            .background(Color.white.opacity(0.2))
                                            .cornerRadius(8)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                            )
                                    }
                                }
                            }
                            .padding()
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.yellow.opacity(0.5), lineWidth: 1)
                            )
                            .padding(.horizontal)
                        }
                        
                        // Loading indicator
                        if isLoading {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                    .tint(.pillrAccent)
                                
                                Text("Checking interaction...")
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .gyroGlassCardStyle(cornerRadius: 16, borderColor: .white.opacity(0.3))
                            .padding(.horizontal)
                        }
                        
                        // Results display
                        if let interaction = searchResult {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Text("Interaction Results")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Text(interaction.severity.rawValue)
                                        .font(.subheadline.bold())
                                        .foregroundColor(.black)
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 10)
                                        .background(Color(hex: interaction.severity.color))
                                        .cornerRadius(12)
                                }
                                
                                Divider()
                                    .background(Color.white.opacity(0.3))
                                
                                Text("\(interaction.drugA) + \(interaction.drugB)")
                                    .font(.system(.title3, design: .rounded).bold())
                                    .foregroundColor(.white)
                                
                                Text(interaction.description)
                                    .foregroundColor(.white.opacity(0.9))
                                    .padding(.vertical, 4)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Recommended Action")
                                        .font(.subheadline.bold())
                                        .foregroundColor(.white.opacity(0.7))
                                    
                                    Text(interaction.recommendedAction)
                                        .foregroundColor(.white)
                                        .padding(.vertical, 4)
                                }
                                
                                Divider()
                                    .background(Color.white.opacity(0.3))
                                
                                Text("Remember: This information is generated by AI and should not replace professional medical advice.")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .multilineTextAlignment(.center)
                                    .padding(.top, 4)
                            }
                            .padding()
                            .gyroGlassCardStyle(cornerRadius: 16, borderColor: .white.opacity(0.3))
                            .padding(.horizontal)
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
            }
            .sheet(isPresented: $showingHistory) {
                InteractionHistoryView()
            }
        }
    }
    
    private func searchInteraction() {
        guard !drugA.isEmpty && !drugB.isEmpty else { return }
        guard openAIService.hasAPIKey() else {
            errorMessage = "Please set an API key first"
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
                    interactionStore.saveInteraction(result)
                    isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    errorMessage = "Error: \(error.localizedDescription)"
                    showingError = true
                    isLoading = false
                }
            }
        }
    }
}

struct InteractionHistoryView: View {
    @ObservedObject private var interactionStore = InteractionStore.shared
    @State private var searchText = ""
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient.pillrBackground
                    .ignoresSafeArea()
                
                VStack {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.white.opacity(0.6))
                        
                        TextField("Search history", text: $searchText)
                            .foregroundColor(.white)
                            .accentColor(.pillrAccent)
                            .onChange(of: searchText) { newValue in
                                interactionStore.searchInteractions(query: newValue)
                            }
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                                interactionStore.clearSearchResults()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    // History list
                    if searchText.isEmpty {
                        if interactionStore.interactionHistory.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "clock.badge.questionmark")
                                    .font(.system(size: 50))
                                    .foregroundColor(.white.opacity(0.5))
                                    .padding(.top, 60)
                                
                                Text("No interaction history yet")
                                    .font(.title3)
                                    .foregroundColor(.white.opacity(0.8))
                                
                                Text("Your medication interaction searches will appear here")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.6))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            List {
                                ForEach(interactionStore.interactionHistory) { interaction in
                                    InteractionListItem(interaction: interaction)
                                        .listRowBackground(Color.clear)
                                }
                            }
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                        }
                    } else {
                        List {
                            if interactionStore.searchResults.isEmpty {
                                Text("No matching results")
                                    .foregroundColor(.white.opacity(0.7))
                                    .listRowBackground(Color.clear)
                            } else {
                                ForEach(interactionStore.searchResults) { interaction in
                                    InteractionListItem(interaction: interaction)
                                        .listRowBackground(Color.clear)
                                }
                            }
                        }
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                    }
                }
                .navigationBarTitle("Interaction History", displayMode: .inline)
                .navigationBarItems(trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                })
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            presentationMode.wrappedValue.dismiss()
                        }
                        .foregroundColor(.pillrAccent)
                    }
                }
            }
        }
    }
}

struct InteractionListItem: View {
    let interaction: DrugInteraction
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(interaction.drugA) + \(interaction.drugB)")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(interaction.severity.rawValue)
                    .font(.caption.bold())
                    .foregroundColor(.black)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 8)
                    .background(Color(hex: interaction.severity.color))
                    .cornerRadius(10)
            }
            
            Text(interaction.description)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(2)
            
            Text(formatDate(interaction.timestamp))
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.vertical, 8)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Previews
struct InteractionSearchView_Previews: PreviewProvider {
    static var previews: some View {
        InteractionSearchView()
            .environmentObject(OpenAIService.shared)
            .environmentObject(InteractionStore.shared)
            .preferredColorScheme(.dark)
    }
}

struct InteractionHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        InteractionHistoryView()
            .environmentObject(InteractionStore.shared)
            .preferredColorScheme(.dark)
    }
} 