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
            ZStack {
                // Background
                Color(hex: "#404C42")
                    .ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    Text("Log: \(medicationToLog.name)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: "#C7C7BD"))
                        .padding(.top, 15)
                        .padding(.horizontal, 16)
                    
                    if let pillCount = remainingPills {
                        Text("\(pillCount) pills remaining")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                    }
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Multiple doses selector
                            if hasMultipleDoses {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Dose")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(Color(hex: "#C7C7BD"))
                                    
                                    Picker("Dose", selection: $selectedDoseIndex) {
                                        ForEach(0..<medicationToLog.reminderTimes.count, id: \.self) { index in
                                            Text("Dose #\(index + 1) (\(formatTime(medicationToLog.reminderTimes[index])))")
                                                .tag(index)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                            }
                            
                            // Skip toggle
                            VStack(alignment: .leading, spacing: 6) {
                                Toggle("Skip This Dose", isOn: $isSkipped)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(hex: "#C7C7BD"))
                                    .tint(Color.pillrAccent)
                                
                                if isSkipped {
                                    Text("Will not reduce pill count")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.6))
                                }
                            }
                            
                            // Time selection
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Time \(isSkipped ? "Skipped" : "Taken")")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(hex: "#C7C7BD"))
                                
                                DatePicker("", selection: $actualTimeTaken)
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .colorScheme(.dark)
                                    .accentColor(Color.pillrAccent)
                            }
                            
                            // Notes
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Notes (Optional)")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(hex: "#C7C7BD"))
                                
                                TextEditor(text: $logNotes)
                                    .frame(height: calculateTextEditorHeight(for: UIScreen.main.bounds.size))
                                    .foregroundColor(Color(hex: "#C7C7BD"))
                                    .padding(6)
                                    .background(Color.black.opacity(0.2))
                                    .cornerRadius(4)
                            }
                            
                            // Submit button
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
                                Text(isSkipped ? "Skip Dose" : "Log Dose")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(hex: "#C7C7BD"))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(isSkipped ? Color.orange.opacity(0.3) : Color.black.opacity(0.3))
                                    .cornerRadius(4)
                            }
                            .padding(.top, 5)
                            .padding(.bottom, keyboardHeight > 0 ? keyboardHeight - 20 : 20)
                        }
                        .padding(16)
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(Color(hex: "#C7C7BD"))
                    }
                }
            }
            .onAppear {
                // Load remaining pill count if available
                remainingPills = store.getRemainingPillCount(for: medicationToLog.id)
                
                // Set default time to the scheduled time for the selected dose
                if hasMultipleDoses && selectedDoseIndex < medicationToLog.reminderTimes.count {
                    actualTimeTaken = medicationToLog.reminderTimes[selectedDoseIndex]
                } else {
                    actualTimeTaken = medicationToLog.timeToTake
                }
                
                // Watch for keyboard
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
    
    private func calculateTextEditorHeight(for size: CGSize) -> CGFloat {
        if horizontalSizeClass == .regular {
            return 120 // iPad
        } else {
            return size.height < 700 ? 80 : 100 // Adjust for different phone sizes
        }
    }
}