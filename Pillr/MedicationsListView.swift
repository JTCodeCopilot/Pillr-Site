//
//  MedicationsListView.swift
//  Pillr
//
//  Created by Justin Tilley on 14/5/2025.
//


import SwiftUI

struct MedicationsListView: View {
    @EnvironmentObject var store: MedicationStore
    @State private var showingLogSheetFor: Medication?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    // Background color - match the exact top gradient color from ContentView
                    LinearGradient.pillrBackground
                    .ignoresSafeArea()
                        
                    List {
                        if store.medications.isEmpty {
                            Text("No medications added yet. Tap '+' to add one.")
                                .foregroundColor(.white.opacity(0.7))
                                .listRowBackground(Color.clear)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 50)
                        } else {
                            ForEach(store.medications) { med in
                                MedicationRow(medication: med, onLogTap: {
                                    showingLogSheetFor = med
                                })
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .padding(.vertical, 4)
                            }
                            .onDelete(perform: store.deleteMedication)
                        }
                    }
                    .listStyle(.plain)
                    .background(Color.clear)
                    .navigationBarHidden(true)
                    // Adjust side padding based on device size
                    .padding(.horizontal, horizontalInsets(for: geometry))
                }
            }
        }
        .navigationViewStyle(.stack)
        .sheet(item: $showingLogSheetFor) { med in
            LogMedicationView(medicationToLog: med)
                .environmentObject(store)
        }
    }
    
    // Calculate proper insets based on screen size
    private func horizontalInsets(for geometry: GeometryProxy) -> CGFloat {
        if horizontalSizeClass == .regular && geometry.size.width > 768 {
            // For iPads and larger screens - prevent content from stretching too much
            return max((geometry.size.width - 768) / 3, 0)
        }
        return 0 // Default - use full width on phones
    }
}

struct MedicationRow: View {
    let medication: Medication
    let onLogTap: () -> Void
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isPressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(medication.name)
                        .font(horizontalSizeClass == .regular ? .title3 : .headline)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                    
                    Text("\(medication.dosage) - \(medication.frequency)")
                        .font(horizontalSizeClass == .regular ? .body : .subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isPressed = true
                        
                        // Reset the press state after a short delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            isPressed = false
                            onLogTap()
                        }
                    }
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: horizontalSizeClass == .regular ? 28 : 22))
                        .foregroundColor(.green.opacity(0.8))
                        .padding(10)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .shadow(color: .white.opacity(0.1), radius: 2, x: 0, y: 0)
                        )
                        .scaleEffect(isPressed ? 0.9 : 1)
                }
                .buttonStyle(.plain)
                .contentShape(Circle()) // Improve tappable area for accessibility
            }
            
            HStack {
                Image(systemName: "clock.fill")
                    .font(.system(size: horizontalSizeClass == .regular ? 14 : 12))
                    .foregroundColor(.white.opacity(0.6))
                
                Text("\(medication.timeToTake, style: .time)")
                    .font(horizontalSizeClass == .regular ? .subheadline : .caption)
                    .foregroundColor(.white.opacity(0.7))
            }

            if let notes = medication.notes, !notes.isEmpty {
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "note.text")
                        .font(.system(size: horizontalSizeClass == .regular ? 14 : 12))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.top, 2)
                    
                    Text(notes)
                        .font(horizontalSizeClass == .regular ? .subheadline : .caption)
                        .italic()
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(3)
                }
            }
        }
        .padding(horizontalSizeClass == .regular ? 16 : 12)
        .gyroGlassCardStyle(
            cornerRadius: 20, 
            material: .ultraThinMaterial,
            borderColor: Color.white.opacity(0.3),
            borderWidth: 1.2,
            shadowOpacity: 0.18,
            shadowRadius: 10,
            shineOpacity: 0.6
        )
    }
}