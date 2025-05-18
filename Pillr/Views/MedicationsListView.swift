//
//  MedicationsListView.swift
//  Pillr
//
//  Created by Justin Tilley on 14/5/2025.
//

import SwiftUI

struct MedicationsListView: View {
    @EnvironmentObject var store: MedicationStore
    @EnvironmentObject var userSettings: UserSettings
    @State private var showingLogSheetFor: Medication?
    @State private var selectedMedicationToEdit: Medication?
    @State private var showingAddSheet = false
    @State private var scrolledOffset: CGFloat = 0
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    
    private var groupedMedications: [(String, [Medication])] {
        let calendar = Calendar.current
        let now = Date()
        let morning = calendar.date(bySettingHour: 5, minute: 0, second: 0, of: now)!
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now)!
        let evening = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: now)!
        let night = calendar.date(bySettingHour: 21, minute: 0, second: 0, of: now)!
        
        var groups: [(String, [Medication])] = []
        
        let morningMeds = store.medications.filter {
            $0.timeToTake >= morning && $0.timeToTake < noon
        }.sorted { $0.timeToTake < $1.timeToTake }
        
        let afternoonMeds = store.medications.filter {
            $0.timeToTake >= noon && $0.timeToTake < evening
        }.sorted { $0.timeToTake < $1.timeToTake }
        
        let eveningMeds = store.medications.filter {
            $0.timeToTake >= evening && $0.timeToTake < night
        }.sorted { $0.timeToTake < $1.timeToTake }
        
        let nightMeds = store.medications.filter {
            $0.timeToTake >= night || $0.timeToTake < morning
        }.sorted { $0.timeToTake < $1.timeToTake }
        
        if !morningMeds.isEmpty { groups.append(("Morning", morningMeds)) }
        if !afternoonMeds.isEmpty { groups.append(("Afternoon", afternoonMeds)) }
        if !eveningMeds.isEmpty { groups.append(("Evening", eveningMeds)) }
        if !nightMeds.isEmpty { groups.append(("Night", nightMeds)) }
        
        return groups
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack(alignment: .top) {
                // Background color
                Color(hex: "#404C42")
                    .ignoresSafeArea(edges: [.top, .leading, .trailing, .bottom])
                
                // Decorative shapes removed - now using consistent styling from ContentView
                
                VStack(spacing: 0) {
                    // Minimal nav bar removed
                    
                    if store.medications.isEmpty {
                        // Minimal empty state
                        VStack(spacing: 20) {
                            Image(systemName: "pills")
                                .font(.system(size: 50))
                                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                                .padding(.bottom, 10)
                            
                            Text("Your medication list is empty")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(Color(hex: "#C7C7BD"))
                            
                            Text("Add your medications to get reminders and track when you take them")
                                .font(.system(size: 14))
                                .multilineTextAlignment(.center)
                                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                                .padding(.horizontal)
                            
                            Button {
                                showingAddSheet = true
                            } label: {
                                Text("Add Medication")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(Color(hex: "#C7C7BD"))
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 20)
                                    .background(Color.black.opacity(0.3))
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color(hex: "#C7C7BD").opacity(0.2), lineWidth: 1)
                                    )
                            }
                        }
                        .padding(30)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Your medication list is empty. Add your first medication.")
                    } else {
                        // Coordinated ScrollView that updates scroll position for parallax
                        ScrollView {
                            VStack(spacing: 24) {
                                // Title
                                HStack {
                                    Text("Taking")
                                        .font(.system(size: 36, weight: .semibold))
                                        .foregroundColor(Color(hex: "#C7C7BD"))
                                    Spacer()
                                }
                                .padding(.horizontal, 4)
                                .padding(.bottom, 12)
                                
                                // All medications in a single list sorted by time
                                VStack(alignment: .leading, spacing: 10) {
                                    // Display all medications sorted by time
                                    ForEach(store.medications.sorted(by: { $0.timeToTake < $1.timeToTake })) { med in
                                        MedicationRow(medication: med, onLogTap: {
                                            showingLogSheetFor = med
                                        }, onEditTap: {
                                            selectedMedicationToEdit = med
                                        })
                                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                                    }
                                }
                                
                                // Space at bottom for better scrolling
                                Spacer(minLength: 40)
                            }
                            .padding(.horizontal, horizontalInsets(for: UIScreen.main.bounds.width))
                            .padding(.top, 10)
                            .background(
                                GeometryReader { geo in
                                    Color.clear.preference(
                                        key: ScrollOffsetPreferenceKey.self,
                                        value: geo.frame(in: .global).minY
                                    )
                                }
                            )
                        }
                        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                            scrolledOffset = -value
                        }
                    }
                }
            }
            
            // Floating Add Button
            Button(action: {
                showingAddSheet = true
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color(hex: "#404C42"))
                    .frame(width: 60, height: 90)
                    .background(Color(hex: "#C7C7BD"))
                    .cornerRadius(50)
                    .shadow(color: Color(hex: "#2F352F").opacity(1), radius: 5, x: 0, y: 0)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 70)  // Increased bottom padding to move button higher
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel("Add new medication")
        }
        .sheet(item: $showingLogSheetFor) { med in
            LogMedicationView(medicationToLog: med)
                .environmentObject(store)
        }
        .sheet(item: $selectedMedicationToEdit) { med in
            NavigationView {
                EditMedicationView(medication: med, onUpdate: {
                    // The store is already updated
                })
                .environmentObject(store)
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            NavigationView {
                AddMedicationView(onAdd: {
                    // Close the sheet after adding
                    showingAddSheet = false
                })
                .environmentObject(store)
            }
        }
    }
    
    // Calculate proper insets based on screen size
    private func horizontalInsets(for width: CGFloat) -> CGFloat {
        if horizontalSizeClass == .regular && width > 768 {
            // For iPads and larger screens - prevent content from stretching too much
            return max((width - 650) / 2, 16)
        }
        return 16 // Default padding for phones
    }
}

// MARK: - Preference Key for Scroll Position
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
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
    @State private var showDetails = false
    
    // Check if the medication was taken today
    private var wasTakenToday: Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return store.logs.contains { log in
            log.medicationID == medication.id &&
            calendar.isDate(calendar.startOfDay(for: log.takenAt), inSameDayAs: today)
        }
    }
    
    // Get next due time status
    private var timeStatus: String {
        let now = Date()
        let minutes = Calendar.current.dateComponents([.minute], from: now, to: medication.timeToTake).minute ?? 0
        
        if minutes < 0 {
            if minutes > -30 {
                return "Just now"
            } else if minutes > -60 {
                return "Past due"
            } else {
                return ""
            }
        } else if minutes < 30 {
            return "Soon"
        } else if minutes < 60 {
            return "In 1 hour"
        } else {
            let hours = minutes / 60
            return "In \(hours) \(hours == 1 ? "hour" : "hours")"
        }
    }
    
    // Get color for time status
    private var timeStatusColor: Color {
        let now = Date()
        let minutes = Calendar.current.dateComponents([.minute], from: now, to: medication.timeToTake).minute ?? 0
        
        if minutes < 0 && minutes > -60 {
            return .orange
        } else if minutes < 0 {
            return .red
        } else if minutes < 30 {
            return .green
        } else {
            return .blue
        }
    }
    
    // Format time for display
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(medication.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: "#C7C7BD"))
                    
                    Text("\(medication.dosage) - \(medication.frequency)")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                    
                    if let notes = medication.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.6))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 6) {
                    Text(timeStatus)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(timeStatusColor)
                    
                    HStack(spacing: 4) {
                        Button(action: {
                            HapticManager.shared.softImpact()
                            onEditTap()
                        }) {
                            Image(systemName: "pencil")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.6))
                                .padding(6)
                        }
                        
                        Button(action: {
                            if !wasTakenToday {
                                HapticManager.shared.successNotification()
                            } else {
                                HapticManager.shared.lightImpact()
                            }
                            onLogTap()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: wasTakenToday ? "checkmark" : "circle")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: "#C7C7BD"))
                                
                                Text(wasTakenToday ? "Taken" : "Take")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "#C7C7BD"))
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(
                                wasTakenToday ?
                                    Color(hex: "#C7C7BD").opacity(0.1) :
                                    Color.black.opacity(0.3)
                            )
                            .cornerRadius(4)
                        }
                    }
                }
            }
            .padding(12)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showDetails.toggle()
                }
            }
            .overlay(
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                            .padding(8)
                    }
                }
            )
            .overlay(
                HStack {
                    Spacer()
                    Text(showDetails ? "Tap to collapse" : "Tap for details")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(1))
                        .padding(.trailing, 24)
                        .padding(.bottom, 12)
                }
                .padding(.bottom, 5),
                alignment: .bottom
            )
            
            if showDetails {
                VStack(alignment: .leading, spacing: 10) {
                    Divider()
                        .background(Color(hex: "#C7C7BD").opacity(0.3))
                        .padding(.horizontal, 12)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        // Section title
                        Text("DETAILS")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                            .padding(.bottom, 4)
                        
                        // Primary time
                        HStack {
                            Text("Primary time:")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                            
                            Text(formatTime(medication.timeToTake))
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "#C7C7BD"))
                        }
                        
                        // Additional times if any
                        if !medication.reminderTimes.isEmpty {
                            Text("Reminder times:")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                            
                            ForEach(0..<medication.reminderTimes.count, id: \.self) { index in
                                Text("• \(formatTime(medication.reminderTimes[index]))")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: "#C7C7BD"))
                                    .padding(.leading, 8)
                            }
                        }
                        
                        // Pill count information if available
                        if let pillCount = medication.pillCount {
                            HStack {
                                Text("Remaining:")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                                
                                Text("\(pillCount) pills")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: "#C7C7BD"))
                            }
                            
                            HStack {
                                Text("Per dose:")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                                
                                Text("\(medication.pillsPerDose) \(medication.pillsPerDose == 1 ? "pill" : "pills")")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: "#C7C7BD"))
                            }
                            
                            if let threshold = medication.refillThreshold {
                                HStack {
                                    Text("Refill alert:")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                                
                                    Text("When below \(threshold) pills")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color(hex: "#C7C7BD"))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
        }
        .background(Color.black.opacity(0.3))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    wasTakenToday ? Color(hex: "#C7C7BD").opacity(0.3) : Color(hex: "#C7C7BD").opacity(0.1),
                    lineWidth: 0.5
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(medication.name), \(medication.dosage), \(medication.frequency), \(formatTimeAccessible(medication.timeToTake))")
        .accessibilityHint(wasTakenToday ? "Already taken today. Double tap to expand details." : "Double tap to log as taken or expand details.")
        .accessibilityAction(.default) {
            if !wasTakenToday {
                onLogTap()
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showDetails.toggle()
                }
            }
        }
        .accessibilityAction(named: wasTakenToday ? "View Details" : "View Details Without Logging") {
            withAnimation(.easeInOut(duration: 0.2)) {
                showDetails.toggle()
            }
        }
    }
    
    // Format time for accessibility
    private func formatTimeAccessible(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// Extension to convert ShapeStyle types to AnyShapeStyle
extension ShapeStyle {
    func anyShapeStyle() -> AnyShapeStyle {
        return AnyShapeStyle(self)
    }
}
