import SwiftUI

struct AISearchMedicationView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var userSettings: UserSettings
    @State private var searchQuery = ""
    @State private var isSearching = false
    @State private var searchResults: [MedicationSearchResult] = []
    @State private var errorMessage: String? = nil
    @State private var showingPremiumUpgrade = false
    
    var onSelectMedication: (MedicationSearchResult) -> Void
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#404C42"),
                    Color(hex: "#3A443D")
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Title and premium badge
                HStack {
                    Text("AI Medication Search")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "#E8E8E0"))
                    
                    Spacer()
                    
                    Text("PREMIUM")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: "#D4A017"))
                        .cornerRadius(6)
                }
                .padding(.horizontal)
                
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Color(hex: "#C7C7BD"))
                        .font(.system(size: 16, weight: .medium))
                    
                    TextField("Search for a medication...", text: $searchQuery)
                        .foregroundColor(Color(hex: "#E8E8E0"))
                        .font(.system(size: 16, weight: .medium))
                        .disableAutocorrection(true)
                        .autocapitalization(.none)
                    
                    if !searchQuery.isEmpty {
                        Button(action: {
                            searchQuery = ""
                            searchResults = []
                            errorMessage = nil
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                                .font(.system(size: 16, weight: .medium))
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: "#C7C7BD").opacity(0.3), lineWidth: 1)
                        )
                )
                .padding(.horizontal)
                
                // Premium required notice (if not premium)
                if !userSettings.isPremiumUser {
                    premiumRequiredView
                } else {
                    // Content
                    VStack {
                        if isSearching {
                            ProgressView()
                                .scaleEffect(1.2)
                                .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#C7C7BD")))
                                .padding()
                        } else if let error = errorMessage {
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(Color(hex: "#FF9800"))
                                    .font(.system(size: 28, weight: .medium))
                                
                                Text(error)
                                    .foregroundColor(Color(hex: "#E8E8E0"))
                                    .multilineTextAlignment(.center)
                                    .padding()
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                        } else if searchResults.isEmpty && !searchQuery.isEmpty {
                            // No results view
                            VStack(spacing: 16) {
                                Image(systemName: "pills.circle")
                                    .font(.system(size: 40))
                                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                                
                                Text("No medications found")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(Color(hex: "#E8E8E0"))
                                
                                Text("Try a different search term or add your medication manually")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                        } else if !searchResults.isEmpty {
                            // Results list
                            ScrollView {
                                LazyVStack(spacing: 16) {
                                    ForEach(searchResults) { result in
                                        medicationResultCard(result)
                                            .onTapGesture {
                                                HapticManager.shared.mediumImpact()
                                                onSelectMedication(result)
                                                dismiss()
                                            }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        } else {
                            // Initial state
                            VStack(spacing: 20) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 40))
                                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                                
                                Text("Search for your medication")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(Color(hex: "#E8E8E0"))
                                
                                Text("Enter a medication name to get information and add it to your list")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 50)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                Spacer()
            }
            .padding(.top, 20)
        }
        .onSubmit(of: .text) {
            if !searchQuery.isEmpty && userSettings.isPremiumUser {
                searchMedications()
            } else if !userSettings.isPremiumUser {
                showingPremiumUpgrade = true
            }
        }
        .onChange(of: searchQuery) { _, newValue in
            if newValue.isEmpty {
                searchResults = []
                errorMessage = nil
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .foregroundColor(Color(hex: "#C7C7BD"))
            }
        }
        .sheet(isPresented: $showingPremiumUpgrade) {
            PremiumUpgradeView()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // Premium required view
    private var premiumRequiredView: some View {
        VStack(spacing: 24) {
            Image(systemName: "crown.fill")
                .foregroundColor(Color(hex: "#D4A017"))
                .font(.system(size: 40))
            
            Text("Premium Feature")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Color(hex: "#E8E8E0"))
            
            Text("AI Medication Search is a premium feature that allows you to quickly find medication information and add it to your list.")
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "#C7C7BD"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            Button(action: {
                showingPremiumUpgrade = true
            }) {
                HStack {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Upgrade to Premium")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(hex: "#D4A017"))
                        .shadow(color: Color(hex: "#D4A017").opacity(0.3), radius: 8, x: 0, y: 4)
                )
            }
            .buttonStyle(ScaleButtonStyle(hapticStyle: .medium))
            .padding(.horizontal, 20)
            .padding(.top, 10)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: "#C7C7BD").opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal)
        .padding(.top, 20)
    }
    
    // Medication result card
    private func medicationResultCard(_ result: MedicationSearchResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Medication name and icon
            HStack {
                Image(systemName: "pill.fill")
                    .foregroundColor(Color(hex: "#C7C7BD"))
                    .font(.system(size: 18, weight: .semibold))
                
                Text(result.name)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(hex: "#E8E8E0"))
                
                Spacer()
                
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(Color(hex: "#C7C7BD"))
                    .font(.system(size: 22, weight: .medium))
            }
            
            // Description
            Text(result.description)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))
                .lineLimit(3)
            
            // Common dosage
            if let dosage = result.commonDosage {
                HStack {
                    Image(systemName: "scalemass.fill")
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                        .font(.system(size: 14))
                    
                    Text("Common dosage: \(dosage)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "#C7C7BD").opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // Search for medications using OpenAI
    private func searchMedications() {
        guard !searchQuery.isEmpty else { return }
        
        isSearching = true
        errorMessage = nil
        searchResults = []
        
        // Simulating AI search for now
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // Mock search results based on query
            let query = searchQuery.lowercased()
            
            if query.contains("aspirin") {
                searchResults.append(MedicationSearchResult(
                    id: UUID().uuidString,
                    name: "Aspirin",
                    description: "A common pain reliever and anti-inflammatory medication that can also be used to reduce fever and prevent blood clots.",
                    commonDosage: "81-325 mg"
                ))
            }
            
            if query.contains("ibuprofen") || query.contains("advil") || query.contains("motrin") {
                searchResults.append(MedicationSearchResult(
                    id: UUID().uuidString,
                    name: "Ibuprofen",
                    description: "A nonsteroidal anti-inflammatory drug (NSAID) used to reduce fever and treat pain or inflammation.",
                    commonDosage: "200-400 mg every 4-6 hours"
                ))
            }
            
            if query.contains("acetaminophen") || query.contains("tylenol") {
                searchResults.append(MedicationSearchResult(
                    id: UUID().uuidString,
                    name: "Acetaminophen",
                    description: "A pain reliever and fever reducer that works by inhibiting the production of prostaglandins in the central nervous system.",
                    commonDosage: "325-650 mg every 4-6 hours"
                ))
            }
            
            if query.contains("lisinopril") {
                searchResults.append(MedicationSearchResult(
                    id: UUID().uuidString,
                    name: "Lisinopril",
                    description: "An ACE inhibitor used to treat high blood pressure and heart failure, and to improve survival after a heart attack.",
                    commonDosage: "10-40 mg once daily"
                ))
            }
            
            if query.contains("metformin") {
                searchResults.append(MedicationSearchResult(
                    id: UUID().uuidString,
                    name: "Metformin",
                    description: "An oral diabetes medicine that helps control blood sugar levels. Used primarily for the treatment of type 2 diabetes.",
                    commonDosage: "500-1000 mg twice daily"
                ))
            }
            
            if query.contains("amoxicillin") {
                searchResults.append(MedicationSearchResult(
                    id: UUID().uuidString,
                    name: "Amoxicillin",
                    description: "A penicillin antibiotic used to treat a wide variety of bacterial infections, such as pneumonia, bronchitis, and infections of the ear, nose, throat, skin, or urinary tract.",
                    commonDosage: "250-500 mg three times daily"
                ))
            }
            
            if query.contains("atorvastatin") || query.contains("lipitor") {
                searchResults.append(MedicationSearchResult(
                    id: UUID().uuidString,
                    name: "Atorvastatin",
                    description: "A statin medication used to prevent cardiovascular disease in those at high risk and treat abnormal lipid levels.",
                    commonDosage: "10-80 mg once daily"
                ))
            }
            
            // If no specific matches but general search term
            if searchResults.isEmpty && (query.contains("blood pressure") || query.contains("hypertension")) {
                searchResults.append(MedicationSearchResult(
                    id: UUID().uuidString,
                    name: "Lisinopril",
                    description: "An ACE inhibitor used to treat high blood pressure and heart failure.",
                    commonDosage: "10-40 mg once daily"
                ))
                
                searchResults.append(MedicationSearchResult(
                    id: UUID().uuidString,
                    name: "Amlodipine",
                    description: "A calcium channel blocker used to treat high blood pressure and coronary artery disease.",
                    commonDosage: "5-10 mg once daily"
                ))
            }
            
            if searchResults.isEmpty && (query.contains("pain") || query.contains("headache")) {
                searchResults.append(MedicationSearchResult(
                    id: UUID().uuidString,
                    name: "Aspirin",
                    description: "A common pain reliever and anti-inflammatory medication.",
                    commonDosage: "325-650 mg every 4-6 hours"
                ))
                
                searchResults.append(MedicationSearchResult(
                    id: UUID().uuidString,
                    name: "Ibuprofen",
                    description: "A nonsteroidal anti-inflammatory drug (NSAID) used to treat pain or inflammation.",
                    commonDosage: "200-400 mg every 4-6 hours"
                ))
                
                searchResults.append(MedicationSearchResult(
                    id: UUID().uuidString,
                    name: "Acetaminophen",
                    description: "A pain reliever and fever reducer with fewer anti-inflammatory properties than NSAIDs.",
                    commonDosage: "325-650 mg every 4-6 hours"
                ))
            }
            
            // If no results at all, show an error
            if searchResults.isEmpty && !query.isEmpty {
                // This would be where we'd integrate with OpenAI in a real implementation
                errorMessage = "No medications found matching '\(searchQuery)'. Try a different search term or add your medication manually."
            }
            
            isSearching = false
        }
    }
}

// Model for medication search results
struct MedicationSearchResult: Identifiable {
    let id: String
    let name: String
    let description: String
    let commonDosage: String?
}

// Preview
struct AISearchMedicationView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AISearchMedicationView(onSelectMedication: { _ in })
                .environmentObject(UserSettings.previewSettings())
        }
        .preferredColorScheme(.dark)
    }
} 
