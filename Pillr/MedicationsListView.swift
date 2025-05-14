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
    @State private var selectedMedicationToEdit: Medication?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    // Background color - match the exact top gradient color from ContentView
                    LinearGradient.pillrBackground
                        .ignoresSafeArea()
                        
                    List {
                        if store.medications.isEmpty {
                            VStack(spacing: 20) {
                                Image(systemName: "pills")
                                    .font(.system(size: 50))
                                    .foregroundColor(.white.opacity(0.5))
                                    .padding(.bottom, 10)
                                
                                Text("No medications added yet")
                                    .font(.headline)
                                    .foregroundColor(.white.opacity(0.7))
                                
                                Text("Tap '+' to add one")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 50)
                            .listRowBackground(Color.clear)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("No medications added yet. Tap plus to add one.")
                        } else {
                            ForEach(store.medications) { med in
                                MedicationRow(medication: med, onLogTap: {
                                    showingLogSheetFor = med
                                }, onEditTap: {
                                    selectedMedicationToEdit = med
                                })
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .padding(.vertical, 4)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        withAnimation {
                                            store.deleteMedication(at: IndexSet(integer: store.medications.firstIndex(of: med) ?? 0))
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .background(Color.clear)
                    .navigationBarHidden(true)
                    // Adjust side padding based on device size
                    .padding(.horizontal, horizontalInsets(for: geometry))
                }
            }
            .background(LinearGradient.pillrBackground.ignoresSafeArea())
            .navigationViewStyle(.stack)
            .sheet(item: $showingLogSheetFor) { med in
                LogMedicationView(medicationToLog: med)
                    .environmentObject(store)
            }
            .sheet(item: $selectedMedicationToEdit) { med in
                NavigationView {
                    EditMedicationView(medication: med, onUpdate: {
                        // This will be called when a medication is updated
                        // We don't need to do anything as the store is already updated
                    })
                    .environmentObject(store)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                selectedMedicationToEdit = nil
                            }
                        }
                    }
                }
            }
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
    let onEditTap: () -> Void
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var store: MedicationStore
    @State private var isPressed = false
    
    // Check if the medication was taken today
    private var wasTakenToday: Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return store.logs.contains { log in
            log.medicationID == medication.id &&
            calendar.isDate(calendar.startOfDay(for: log.takenAt), inSameDayAs: today)
        }
    }

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
                
                // Edit Button
                Button {
                    onEditTap()
                } label: {
                    Image(systemName: "pencil.circle")
                        .font(.system(size: horizontalSizeClass == .regular ? 24 : 20))
                        .foregroundColor(Color.white.opacity(0.8))
                        .padding(8)
                }
                .buttonStyle(.plain)
                .contentShape(Circle())
                .accessibilityLabel("Edit \(medication.name)")
                
                // Log Button
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
                    Image(systemName: wasTakenToday ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: horizontalSizeClass == .regular ? 28 : 22))
                        .foregroundColor(wasTakenToday ? Color.green.opacity(0.8) : Color.white.opacity(0.8))
                        .padding(10)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .shadow(color: .white.opacity(0.1), radius: 2, x: 0, y: 0)
                        )
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.4),
                                            Color.white.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.5
                                )
                        )
                        .scaleEffect(isPressed ? 0.9 : 1)
                }
                .buttonStyle(.plain)
                .contentShape(Circle()) // Improve tappable area for accessibility
                .accessibilityLabel("Log \(medication.name) taken")
            }
            
            HStack {
                Image(systemName: "clock.fill")
                    .font(.system(size: horizontalSizeClass == .regular ? 14 : 12))
                    .foregroundColor(.white.opacity(0.6))
                
                Text("\(medication.timeToTake, style: .time)")
                    .font(horizontalSizeClass == .regular ? .subheadline : .caption)
                    .foregroundColor(.white.opacity(0.7))
                    .accessibilityLabel("Time to take: \(formatTimeAccessible(medication.timeToTake))")
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(medication.name), \(medication.dosage), \(medication.frequency), \(formatTimeAccessible(medication.timeToTake))")
        .accessibilityHint("Double tap to log as taken")
    }
    
    // Format time for accessibility
    private func formatTimeAccessible(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}