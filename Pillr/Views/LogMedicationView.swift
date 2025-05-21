//
//  LogMedicationView.swift
//  Pillr
//
//  Created by Justin Tilley on 14/5/2025.
//


import SwiftUI
import UIKit

struct LogMedicationView: View {
    @EnvironmentObject var store: MedicationStore
    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme

    let medicationToLog: Medication
    @State private var actualTimeTaken: Date = Date()
    @State private var logNotes: String = ""
    @State private var keyboardHeight: CGFloat = 0
    @State private var remainingPills: Int?
    @State private var selectedDoseIndex: Int = 0
    @State private var showQuickLogOption: Bool = false
    
    // Whether this medication has multiple doses
    private var hasMultipleDoses: Bool {
        return !medicationToLog.reminderTimes.isEmpty
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#404C42")
                    .ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    HStack {
                        Text(medicationToLog.name)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Color(hex: "#C7C7BD"))
                        Spacer()
                        if let pillCount = remainingPills {
                            Text("\(pillCount) left")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.black.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.top, 20)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12) // Added bottom padding for separation
                    
                    // Removed Quick log section
                    // Always show detailed view
                    ScrollView {
                        VStack(spacing: 20) {
                            // Multiple doses selector
                            if hasMultipleDoses {
                                VStack(alignment: .leading) {
                                    Text("DOSE")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                                        .padding(.bottom, 4)
                                    
                                    Picker("Dose", selection: $selectedDoseIndex) {
                                        ForEach(0..<medicationToLog.reminderTimes.count, id: \.self) { index in
                                            Text("Dose #\(index + 1) (\(formatTime(medicationToLog.reminderTimes[index])))")
                                                .tag(index)
                                                .foregroundColor(Color(hex: "#C7C7BD"))
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .accentColor(Color(hex: "#C7C7BD"))
                                    .padding(.horizontal, -8)
                                }
                                .padding()
                                .background(Color.black.opacity(0.2))
                                .cornerRadius(10)
                            }
                            
                            // Log Details
                            VStack(alignment: .leading, spacing: 12) {
                                // Time selection - combined date and time
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "calendar.badge.clock")
                                            .foregroundColor(Color(hex: "#C7C7BD"))
                                            .frame(width: 25, alignment: .center)
                                        
                                        Text("Time Taken") // Label is always "Time Taken"
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(Color(hex: "#C7C7BD"))
                                        
                                        Spacer()
                                    }
                                    
                                    DatePicker("", selection: $actualTimeTaken, displayedComponents: [.date, .hourAndMinute]) // Combined date and time
                                        .datePickerStyle(.graphical) // Restored graphical style
                                        .labelsHidden()
                                        .colorScheme(.dark) // Assuming dark theme
                                        .accentColor(Color(hex: "#81C784")) // Restored softer green
                                        .padding(.top, 5)
                                }
                            }
                            .padding()
                            .background(Color.black.opacity(0.25))
                            .cornerRadius(12)
                            
                            // Notes
                            VStack(alignment: .leading, spacing: 8) {
                                // Notes Title
                                HStack {
                                    Image(systemName: "square.and.pencil") // Restored icon
                                        .foregroundColor(Color(hex: "#C7C7BD"))
                                        .frame(width: 25, alignment: .leading)
                                    
                                    Text("Notes (Optional)") // Restored title case
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(Color(hex: "#C7C7BD"))
                                    Spacer()
                                }
                                .padding(.bottom, 4)

                                ZStack(alignment: .topLeading) {
                                    TextEditor(text: $logNotes)
                                        .frame(minHeight: 100, maxHeight: 200)
                                        .foregroundColor(Color(hex: "#E0E0E0"))
                                        .scrollContentBackground(.hidden)
                                        .background(Color.clear)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 6)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color(hex: "#C7C7BD").opacity(0.2), lineWidth: 1)
                                        )

                                    if logNotes.isEmpty {
                                        Text("Add any notes about this dose (e.g., side effects, reminders)...")
                                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.5))
                                            .padding(.leading, 9)
                                            .padding(.top, 14)
                                            .allowsHitTesting(false)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.black.opacity(0.25))
                            .cornerRadius(12)
                            
                            // Submit buttons area
                            HStack(spacing: 12) {
                                if medicationToLog.frequency != "As needed" {
                                    Button {
                                        processDoseAction(skipped: true)
                                    } label: {
                                        Text("Skip")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 16)
                                            .background(Color.orange.opacity(0.9))
                                            .cornerRadius(12)
                                    }
                                }
                                
                                Button {
                                    processDoseAction(skipped: false)
                                } label: {
                                    Text("Log") // Changed from "Log Dose Taken"
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(Color(hex: "#3A443D"))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(Color(hex: "#81C784").opacity(0.8))
                                        .cornerRadius(12)
                                }
                            }
                            .padding(.top, 10)
                            .padding(.bottom, keyboardHeight > 0 ? keyboardHeight + 10 : 20)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16) // Reduced top padding for ScrollView content
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline) // Keep inline
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Log Details")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hex: "#C7C7BD"))
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.system(size: 17)) // Standard weight
                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8)) // Slightly dimmer
                    .hapticFeedback(.light)
                }
            }
            .onAppear {
                // Fetch remaining pills when the view appears
                remainingPills = store.getRemainingPillCount(for: medicationToLog.id)
                // Set default time for the dose if applicable
                if hasMultipleDoses, selectedDoseIndex < medicationToLog.reminderTimes.count {
                    actualTimeTaken = medicationToLog.reminderTimes[selectedDoseIndex]
                } else if !hasMultipleDoses {
                    actualTimeTaken = medicationToLog.timeToTake // Fallback to single timeToTake
                }
                
                // Add keyboard observers
                NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
                    guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
                    keyboardHeight = keyboardFrame.height
                }
                NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                    keyboardHeight = 0
                }
            }
            .onDisappear {
                // Remove observers
                NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
                NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    // Just dismiss the keyboard when pressed
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), 
                                                   to: nil, 
                                                   from: nil, 
                                                   for: nil)
                }
                .foregroundColor(Color(hex: "#C7C7BD"))
            }
        }
    }
    
    // Renamed and refactored from confirmLogOrSkip
    private func processDoseAction(skipped: Bool) {
        actualTimeTaken = Date() // Set to current time on action
        
        if skipped {
             store.skipMedication(
                 medication: medicationToLog,
                 actualTime: actualTimeTaken,
                 notes: logNotes.isEmpty ? nil : logNotes,
                 reminderIndex: hasMultipleDoses ? selectedDoseIndex : nil
             )
            HapticManager.shared.warningNotification() // Trigger warning haptic for skip
        } else {
            store.logMedicationTaken(
                medication: medicationToLog,
                actualTime: actualTimeTaken,
                notes: logNotes.isEmpty ? nil : logNotes,
                skipped: false, 
                reminderIndex: hasMultipleDoses ? selectedDoseIndex : nil
            )
            HapticManager.shared.successNotification() // Trigger success haptic for log
        }
        dismiss()
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func calculateTextEditorHeight(for size: CGSize) -> CGFloat {
        if horizontalSizeClass == .regular {
            return 120
        } else {
            return size.height < 700 ? 80 : 100
        }
    }
}

extension View {
    func hapticFeedback(_ style: HapticStyle) -> some View {
        self.onTapGesture {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(
                style == .success ? .success : .warning
            )
        }
    }
}
