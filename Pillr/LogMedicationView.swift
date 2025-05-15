//
//  LogMedicationView.swift
//  Pillr
//
//  Created by Justin Tilley on 14/5/2025.
//


import SwiftUI

struct LogMedicationView: View {
    @EnvironmentObject var store: MedicationStore
    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let medicationToLog: Medication
    @State private var actualTimeTaken: Date = Date()
    @State private var logNotes: String = ""
    @State private var keyboardHeight: CGFloat = 0
    @State private var isSkipped: Bool = false
    @State private var remainingPills: Int?
    @State private var selectedDoseIndex: Int = 0
    
    // Whether this medication has multiple doses
    private var hasMultipleDoses: Bool {
        return !medicationToLog.reminderTimes.isEmpty
    }

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    // Use the same background as ContentView for consistency in sheets
                    LinearGradient.pillrBackground
                        .ignoresSafeArea()
                    
                    ScrollView {
                        VStack(spacing: calculateVerticalSpacing(for: geometry)) {
                            Text("Log: \(medicationToLog.name)")
                                .font(horizontalSizeClass == .regular ? .title : .title2).bold()
                                .foregroundColor(.white)
                                .padding(.top)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if let pillCount = remainingPills {
                                HStack {
                                    Image(systemName: "pills")
                                        .foregroundColor(.white.opacity(0.8))
                                    Text("\(pillCount) pills remaining")
                                        .foregroundColor(.white.opacity(0.8))
                                        .font(.subheadline)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.bottom, 10)
                            }
                            
                            // If medication has multiple doses, show a dose selector
                            if hasMultipleDoses {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Which dose are you logging?")
                                        .font(.headline)
                                        .foregroundColor(.white.opacity(0.9))
                                    
                                    Picker("Dose", selection: $selectedDoseIndex) {
                                        ForEach(0..<medicationToLog.reminderTimes.count, id: \.self) { index in
                                            Text("Dose #\(index + 1) (\(formatTime(medicationToLog.reminderTimes[index])))")
                                                .foregroundColor(.white)
                                                .tag(index)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .padding(10)
                                    .background(
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Material.ultraThinMaterial)
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Color.pillrNavy.opacity(0.1))
                                        }
                                    )
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [
                                                        Color.white.opacity(0.5),
                                                        Color.white.opacity(0.2)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1
                                            )
                                    )
                                }
                                .padding(.bottom, 5)
                            }
                            
                            // Skip Toggle
                            VStack(alignment: .leading, spacing: 5) {
                                Toggle(isOn: $isSkipped) {
                                    Text("Skip This Dose")
                                        .font(.headline)
                                        .foregroundColor(.white.opacity(0.9))
                                }
                                .toggleStyle(SwitchToggleStyle(tint: Color.pillrAccent))
                                .padding(10)
                                .background(
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Material.ultraThinMaterial)
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.pillrNavy.opacity(0.1))
                                    }
                                )
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.5),
                                                    Color.white.opacity(0.2)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                )
                                
                                if isSkipped {
                                    Text("This medication will be marked as skipped and won't reduce your pill count")
                                        .font(.footnote)
                                        .foregroundColor(.white.opacity(0.7))
                                        .padding(.horizontal, 10)
                                        .padding(.bottom, 5)
                                }
                            }
                            .accessibilityLabel("Skip this medication dose")

                            VStack(alignment: .leading) {
                                Text("Time \(isSkipped ? "Skipped" : "Taken")")
                                    .font(.headline)
                                    .foregroundColor(.white.opacity(0.9))
                                DatePicker("Time \(isSkipped ? "Skipped" : "Taken")", selection: $actualTimeTaken)
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .padding(10)
                                    .background(
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Material.ultraThinMaterial)
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Color.pillrNavy.opacity(0.1))
                                        }
                                    )
                                    .cornerRadius(10)
                                    .colorScheme(.dark)
                                    .accentColor(.cyan)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [
                                                        Color.white.opacity(0.5),
                                                        Color.white.opacity(0.2)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1
                                            )
                                    )
                                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                            }

                            VStack(alignment: .leading) {
                                Text("Notes (Optional)")
                                    .font(.headline)
                                    .foregroundColor(.white.opacity(0.9))
                                TextEditor(text: $logNotes)
                                    .frame(height: calculateTextEditorHeight(for: geometry))
                                    .glassTextEditorStyle()
                            }

                            Button {
                                if isSkipped {
                                    store.skipMedication(
                                        medication: medicationToLog, 
                                        actualTime: actualTimeTaken, 
                                        notes: logNotes.isEmpty ? nil : logNotes,
                                        reminderIndex: hasMultipleDoses ? selectedDoseIndex : nil
                                    )
                                } else {
                                    store.logMedicationTaken(
                                        medication: medicationToLog, 
                                        actualTime: actualTimeTaken, 
                                        notes: logNotes.isEmpty ? nil : logNotes,
                                        skipped: false,
                                        reminderIndex: hasMultipleDoses ? selectedDoseIndex : nil
                                    )
                                }
                                dismiss()
                            } label: {
                                Text(isSkipped ? "Confirm Skip" : "Confirm Log")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(isSkipped ? Color.orange.opacity(0.7) : Color.pillrNavy.opacity(1.2))
                                    .cornerRadius(15)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 15)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                            }
                            .padding(.bottom, keyboardHeight > 0 ? keyboardHeight - 20 : 0)
                        }
                        .padding(calculateHorizontalPadding(for: geometry))
                        .gyroGlassCardStyle(
                            cornerRadius: 25, 
                            material: .regularMaterial, 
                            borderColor: Color.white.opacity(0.25),
                            shadowOpacity: 0.18,
                            shadowRadius: 15,
                            shineOpacity: 0.5
                        )
                        .padding(calculateHorizontalPadding(for: geometry))
                        .frame(
                            width: calculateMaxWidth(for: geometry),
                            alignment: .center
                        )
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(.white)
                    }
                }
            }
            .background(LinearGradient.pillrBackground.ignoresSafeArea())
            .onAppear {
                // Load remaining pill count if available
                remainingPills = store.getRemainingPillCount(for: medicationToLog.id)
                
                // Set default time to the scheduled time for the selected dose
                if hasMultipleDoses && selectedDoseIndex < medicationToLog.reminderTimes.count {
                    actualTimeTaken = medicationToLog.reminderTimes[selectedDoseIndex]
                } else {
                    actualTimeTaken = medicationToLog.timeToTake
                }
                
                NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
                    if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                        keyboardHeight = keyboardFrame.height
                    }
                }
                
                NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                    keyboardHeight = 0
                }
            }
            .onChange(of: selectedDoseIndex) { newIndex in
                // Update the time when the selected dose changes
                if hasMultipleDoses && newIndex < medicationToLog.reminderTimes.count {
                    actualTimeTaken = medicationToLog.reminderTimes[newIndex]
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // Format time for display
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
    
    // Calculate adaptive spacing values
    private func calculateVerticalSpacing(for geometry: GeometryProxy) -> CGFloat {
        horizontalSizeClass == .regular ? 25 : 20
    }
    
    private func calculateHorizontalPadding(for geometry: GeometryProxy) -> CGFloat {
        if horizontalSizeClass == .regular {
            return 24 // iPad
        } else {
            return geometry.size.width < 375 ? 12 : 16 // Small vs regular phone
        }
    }
    
    private func calculateMaxWidth(for geometry: GeometryProxy) -> CGFloat {
        if horizontalSizeClass == .regular && geometry.size.width > 768 {
            return 650 // Constrain width on larger iPads
        }
        return geometry.size.width // Full width on phones
    }
    
    private func calculateTextEditorHeight(for geometry: GeometryProxy) -> CGFloat {
        if horizontalSizeClass == .regular {
            return 150 // Taller on iPad
        } else {
            // Adjust based on screen size for phones
            return geometry.size.height < 700 ? 80 : 100
        }
    }
}