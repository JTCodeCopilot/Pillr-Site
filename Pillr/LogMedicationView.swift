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
    @Environment(\.colorScheme) private var colorScheme

    let medicationToLog: Medication
    @State private var actualTimeTaken: Date = Date()
    @State private var logNotes: String = ""
    @State private var keyboardHeight: CGFloat = 0
    @State private var isSkipped: Bool = false
    @State private var remainingPills: Int?
    @State private var selectedDoseIndex: Int = 0
    @State private var showQuickLogOption: Bool = true
    
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
                    if showQuickLogOption {
                        Text("Log Medication")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Color(hex: "#C7C7BD"))
                            .padding(.top, 16)
                            .padding(.horizontal, 16)
                        
                        Text(medicationToLog.name)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(Color(hex: "#C7C7BD"))
                            .padding(.horizontal, 16)
                            .padding(.top, 2)
                        
                        if let pillCount = remainingPills {
                            Text("\(pillCount) pills remaining")
                                .font(.system(size: 15))
                                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                                .padding(.horizontal, 16)
                                .padding(.top, 4)
                        }
                    } else {
                        Text("Log: \(medicationToLog.name)")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Color(hex: "#C7C7BD"))
                            .padding(.top, 16)
                            .padding(.horizontal, 16)
                        
                        if let pillCount = remainingPills {
                            Text("\(pillCount) pills remaining")
                                .font(.system(size: 15))
                                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                                .padding(.horizontal, 16)
                                .padding(.top, 2)
                        }
                    }
                    
                    // Quick log section
                    if showQuickLogOption {
                        VStack(spacing: 16) {
                            HStack(spacing: 40) {
                                Spacer()
                                
                                Button {
                                    // Quick log as taken
                                    store.logMedicationTaken(
                                        medication: medicationToLog,
                                        actualTime: Date(),
                                        notes: nil,
                                        skipped: false,
                                        reminderIndex: hasMultipleDoses ? selectedDoseIndex : nil
                                    )
                                    dismiss()
                                } label: {
                                    VStack(spacing: 8) {
                                        ZStack {
                                            Circle()
                                                .fill(Color(hex: "#C7C7BD").opacity(0.15))
                                                .frame(width: 60, height: 60)
                                            
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 26, weight: .medium))
                                                .foregroundColor(Color(hex: "#C7C7BD"))
                                        }
                                        
                                        Text("Taken")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(Color(hex: "#C7C7BD"))
                                    }
                                }
                                
                                Button {
                                    // Quick skip
                                    store.skipMedication(
                                        medication: medicationToLog,
                                        actualTime: Date(),
                                        notes: nil,
                                        reminderIndex: hasMultipleDoses ? selectedDoseIndex : nil
                                    )
                                    dismiss()
                                } label: {
                                    VStack(spacing: 8) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.red.opacity(0.15))
                                                .frame(width: 60, height: 60)
                                            
                                            Image(systemName: "xmark")
                                                .font(.system(size: 26, weight: .medium))
                                                .foregroundColor(.red)
                                        }
                                        
                                        Text("Skip")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(Color(hex: "#C7C7BD"))
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding(.vertical, 30)
                            
                            Button {
                                withAnimation {
                                    showQuickLogOption = false
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "square.and.pencil")
                                    Text("Add Details")
                                }
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Color(hex: "#C7C7BD"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.black.opacity(0.2))
                                .cornerRadius(10)
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                        }
                    } else {
                        ScrollView {
                            VStack(spacing: 20) {
                                // Multiple doses selector
                                if hasMultipleDoses {
                                    VStack(alignment: .leading) {
                                        Text("DOSE")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                                            .padding(.bottom, 8)
                                        
                                        Picker("Dose", selection: $selectedDoseIndex) {
                                            ForEach(0..<medicationToLog.reminderTimes.count, id: \.self) { index in
                                                Text("Dose #\(index + 1) (\(formatTime(medicationToLog.reminderTimes[index])))")
                                                    .tag(index)
                                                    .foregroundColor(Color(hex: "#C7C7BD"))
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .accentColor(Color(hex: "#C7C7BD"))
                                    }
                                    .padding()
                                    .background(Color.black.opacity(0.2))
                                    .cornerRadius(10)
                                }
                                
                                // Log Details
                                VStack(alignment: .leading) {
                                    Text("DETAILS")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                                        .padding(.bottom, 8)
                                    
                                    // Skip toggle
                                    Toggle(isOn: $isSkipped) {
                                        HStack {
                                            Image(systemName: isSkipped ? "xmark.circle" : "checkmark.circle")
                                                .foregroundColor(isSkipped ? .red : Color(hex: "#C7C7BD"))
                                                .frame(width: 25, alignment: .center)
                                            
                                            Text(isSkipped ? "Skip This Dose" : "Take This Dose")
                                                .font(.system(size: 16))
                                                .foregroundColor(Color(hex: "#C7C7BD"))
                                        }
                                    }
                                    .toggleStyle(SwitchToggleStyle(tint: Color.accentColor))
                                    
                                    if isSkipped {
                                        HStack {
                                            Image(systemName: "info.circle")
                                                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                                                .frame(width: 25, alignment: .center)
                                            
                                            Text("Will not reduce pill count")
                                                .font(.system(size: 14))
                                                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                                        }
                                        .padding(.top, 4)
                                    }
                                    
                                    Divider()
                                        .background(Color(hex: "#C7C7BD").opacity(0.2))
                                        .padding(.vertical, 8)
                                    
                                    // Time selection
                                    HStack {
                                        Image(systemName: "clock")
                                            .foregroundColor(Color(hex: "#C7C7BD"))
                                            .frame(width: 25, alignment: .center)
                                        
                                        Text("Time \(isSkipped ? "Skipped" : "Taken")")
                                            .font(.system(size: 16))
                                            .foregroundColor(Color(hex: "#C7C7BD"))
                                        
                                        Spacer()
                                        
                                        DatePicker("", selection: $actualTimeTaken)
                                            .datePickerStyle(.compact)
                                            .labelsHidden()
                                            .colorScheme(.dark)
                                            .accentColor(Color(hex: "#C7C7BD"))
                                    }
                                }
                                .padding()
                                .background(Color.black.opacity(0.2))
                                .cornerRadius(10)
                                
                                // Notes
                                VStack(alignment: .leading) {
                                    Text("NOTES")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                                        .padding(.bottom, 8)
                                    
                                    HStack(alignment: .top) {
                                        Image(systemName: "note.text")
                                            .foregroundColor(Color(hex: "#C7C7BD"))
                                            .frame(width: 25, alignment: .center)
                                            .padding(.top, 3)
                                        
                                        TextEditor(text: $logNotes)
                                            .frame(minHeight: 100)
                                            .foregroundColor(Color(hex: "#C7C7BD"))
                                            .scrollContentBackground(.hidden)
                                            .background(Color.clear)
                                            .overlay(
                                                Group {
                                                    if logNotes.isEmpty {
                                                        Text("Optional notes")
                                                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.5))
                                                            .padding(.top, 8)
                                                            .padding(.leading, 5)
                                                            .allowsHitTesting(false)
                                                            .frame(maxWidth: .infinity, alignment: .leading)
                                                    }
                                                }
                                            )
                                    }
                                }
                                .padding()
                                .background(Color.black.opacity(0.2))
                                .cornerRadius(10)
                                
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
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(Color(hex: "#404C42"))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(isSkipped ? Color.red : Color(hex: "#C7C7BD"))
                                        .cornerRadius(10)
                                }
                                .padding(.top, 5)
                                .padding(.bottom, keyboardHeight > 0 ? keyboardHeight : 10)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 20)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !showQuickLogOption {
                        Button(isSkipped ? "Skip" : "Log") {
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
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "#C7C7BD"))
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#C7C7BD"))
                }
            }
            .onAppear {
                // Load the remaining pills if tracking is enabled
                if let pillCount = medicationToLog.pillCount {
                    remainingPills = pillCount
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
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
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