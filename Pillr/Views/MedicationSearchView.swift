import SwiftUI

struct MedicationSearchView: View {
    @StateObject private var searchService = MedicationSearchService()
    @Environment(\.dismiss) var dismiss
    @State private var searchQuery = ""
    @Binding var selectedMedication: String
    @State private var searchTask: Task<Void, Never>?
    @State private var expandedIds: Set<UUID> = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "pills.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "#C7C7BD"))
                    .padding(.trailing, 4)
                
                Text("Search Medication")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(hex: "#C7C7BD"))
                
                Spacer()
                
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                    .padding(.leading, 4)
                
                TextField("Search for a medication", text: $searchQuery)
                    .foregroundColor(Color(hex: "#C7C7BD"))
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .font(.system(size: 16))
                    .onChange(of: searchQuery) { newValue in
                        // Debounce the search to avoid too many API calls
                        searchTask?.cancel()
                        guard !newValue.isEmpty else {
                            searchService.searchResults = []
                            return
                        }
                        
                        searchTask = Task {
                            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
                            if !Task.isCancelled {
                                await searchService.searchMedications(query: newValue)
                            }
                        }
                    }
                
                if !searchQuery.isEmpty {
                    Button(action: {
                        searchQuery = ""
                        searchService.searchResults = []
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                    }
                    .padding(.trailing, 4)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.25))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(hex: "#C7C7BD").opacity(0.15), lineWidth: 1)
                    )
            )
            .cornerRadius(12)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            
            if searchService.isLoading {
                // Loading indicator
                VStack {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.2))
                            .frame(width: 80, height: 80)
                        
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#C7C7BD")))
                            .scaleEffect(1.5)
                    }
                    
                    Text("Searching...")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                        .padding(.top, 16)
                    Spacer()
                }
            } else if let error = searchService.error {
                // Error view
                VStack {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.2))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: error.contains("network") || error.contains("internet") || error.contains("connection") ? 
                              "wifi.exclamationmark" : "exclamationmark.triangle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.orange)
                    }
                    .padding(.bottom, 16)
                    
                    Text(error)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(Color(hex: "#C7C7BD"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    if error.contains("premium") {
                        Button {
                            dismiss()
                            // We'll need to show settings view here in a real implementation
                        } label: {
                            Text("Go to Settings")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color(hex: "#404C42"))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color(hex: "#C7C7BD"))
                                .cornerRadius(8)
                                .padding(.top, 16)
                        }
                    } else {
                        Button {
                            if !searchQuery.isEmpty {
                                Task {
                                    await searchService.searchMedications(query: searchQuery)
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 14))
                                Text("Try Again")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .foregroundColor(Color(hex: "#404C42"))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(hex: "#C7C7BD"))
                            .cornerRadius(8)
                            .padding(.top, 16)
                        }
                    }
                    
                    Spacer()
                }
            } else if searchService.searchResults.isEmpty && !searchQuery.isEmpty {
                // No results view
                VStack {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.2))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.6))
                    }
                    .padding(.bottom, 16)
                    
                    Text("No medications found")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(Color(hex: "#C7C7BD"))
                    
                    Text("Try a different search term")
                        .font(.system(size: 15))
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                        .padding(.top, 4)
                    Spacer()
                }
            } else {
                // Results list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(searchService.searchResults) { result in
                            ZStack {
                                // Main content (tappable)
                                Button(action: {
                                    selectedMedication = result.name.trimmingCharacters(in: .whitespacesAndNewlines)
                                    dismiss()
                                }) {
                                    // This invisible overlay ensures the whole card is tappable
                                    Color.clear
                                }
                                
                                // Content (not directly tappable)
                                VStack(spacing: 0) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "pill.fill")
                                            .font(.system(size: 22))
                                            .foregroundColor(Color(hex: "#C7C7BD"))
                                            .frame(width: 40, height: 40)
                                            .background(Color.black.opacity(0.3))
                                            .cornerRadius(8)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(result.name.trimmingCharacters(in: .whitespacesAndNewlines))
                                                .font(.system(size: 17, weight: .semibold))
                                                .foregroundColor(Color(hex: "#C7C7BD"))
                                            
                                            if !expandedIds.contains(result.id) {
                                                Text(result.description.trimmingCharacters(in: .whitespacesAndNewlines))
                                                    .font(.system(size: 14))
                                                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                                                    .lineLimit(1)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        HStack(spacing: 12) {
                                            Button {
                                                withAnimation(.easeInOut(duration: 0.2)) {
                                                    if expandedIds.contains(result.id) {
                                                        expandedIds.remove(result.id)
                                                    } else {
                                                        expandedIds.insert(result.id)
                                                    }
                                                }
                                            } label: {
                                                Image(systemName: expandedIds.contains(result.id) ? "chevron.up" : "chevron.down")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                                                    .padding(6)
                                                    .background(Circle().fill(Color.black.opacity(0.2)))
                                            }
                                            .buttonStyle(BorderlessButtonStyle()) // Prevents event propagation to parent
                                            
                                            Image(systemName: "checkmark.circle")
                                                .font(.system(size: 20))
                                                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.6))
                                        }
                                    }
                                    
                                    // Expanded description
                                    if expandedIds.contains(result.id) {
                                        VStack {
                                            Divider()
                                                .background(Color(hex: "#C7C7BD").opacity(0.2))
                                                .padding(.vertical, 8)
                                        
                                            Text(result.description.trimmingCharacters(in: .whitespacesAndNewlines))
                                                .font(.system(size: 14))
                                                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .padding(.leading, 52)
                                        .padding(.trailing, 16)
                                        .transition(.opacity)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.black.opacity(0.2))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color(hex: "#C7C7BD").opacity(0.15), lineWidth: 1)
                                    )
                            )
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            
            // Note about API usage
            if !OpenAIService.shared.isPremiumMode {
                VStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.yellow)
                        
                        Text("Premium Feature")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                    }
                    
                    Text("Powered by OpenAI")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.5))
                        .padding(.bottom, 12)
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.2))
                .padding(.top, 10)
            }
        }
        .background(Color(hex: "#404C42"))
        .onAppear {
            if !searchQuery.isEmpty {
                Task {
                    await searchService.searchMedications(query: searchQuery)
                }
            }
        }
        .onDisappear {
            // Cancel any pending search task
            searchTask?.cancel()
        }
    }
}

struct MedicationSearchView_Previews: PreviewProvider {
    @State static var selectedMed = ""
    
    static var previews: some View {
        MedicationSearchView(selectedMedication: $selectedMed)
            .preferredColorScheme(.dark)
    }
} 
