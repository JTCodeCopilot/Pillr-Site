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
        ZStack(alignment: .top) {
            // Background gradient
            LinearGradient.pillrBackground
                .ignoresSafeArea()
            
            // Decorative shapes
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.2))
                    .frame(width: 200, height: 200)
                    .blur(radius: 90)
                    .offset(x: -150, y: -50)
                
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 250, height: 250)
                    .blur(radius: 80)
                    .offset(x: 170, y: 100)
            }
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom nav bar with parallax effect
                HStack {
                    Text("")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .opacity(1 - min(scrolledOffset / 80, 0.6))
                        .padding(.leading)
                        .shadow(color: .black.opacity(0.1), radius: 1)
                    
                    Spacer()
                    
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.blue.opacity(0.7), Color.purple.opacity(0.8)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                    Circle()
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                }
                            )
                            .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 3)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel("Add new medication")
                    .padding(.trailing)
                }
                .padding(.top, 16)
                .padding(.bottom, 8)
                .background(
                    LinearGradient.pillrBackground
                        .opacity(min(scrolledOffset / 80, 0.9))
                        .ignoresSafeArea()
                )
                .zIndex(1)
                
                if store.medications.isEmpty {
                    // Enhanced empty state
                    VStack(spacing: 25) {
                        Image(systemName: "pills.circle")
                            .font(.system(size: 80))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue.opacity(0.9), .purple.opacity(0.7)],
                                    startPoint: .topLeading, 
                                    endPoint: .bottomTrailing
                                )
                            )
                            .padding()
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.15))
                                    .padding(-15)
                            )
                            .shadow(color: .black.opacity(0.1), radius: 10)
                        
                        Text("Your medication list is empty")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.white)
                        
                        Text("Add your medications to get reminders \nand track when you take them")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal)
                        
                        Button {
                            showingAddSheet = true
                        } label: {
                            Text("Add Your First Medication")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.vertical, 14)
                                .padding(.horizontal, 24)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .padding(.top, 10)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Your medication list is empty. Add your first medication.")
                } else {
                    // Coordinated ScrollView that updates scroll position for parallax
                    ScrollView {
                        VStack(spacing: 24) {
                            ForEach(groupedMedications, id: \.0) { group in
                                VStack(alignment: .leading, spacing: 12) {
                                    // Time period header
                                    HStack(alignment: .firstTextBaseline) {
                                        Text(group.0)
                                            .font(.system(.headline, design: .rounded))
                                            .foregroundColor(.white.opacity(0.9))
                                        
                                        Spacer()
                                        
                                        Text("\(group.1.count) \(group.1.count == 1 ? "med" : "meds")")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                    .padding(.horizontal)
                                    
                                    // Medications for this time period
                                    ForEach(group.1) { med in
                                        MedicationRow(medication: med, onLogTap: {
                                            showingLogSheetFor = med
                                        }, onEditTap: {
                                            selectedMedicationToEdit = med
                                        })
                                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                                    }
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
                .navigationBarItems(leading: Button("Cancel") {
                    selectedMedicationToEdit = nil
                })
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            NavigationView {
                AddMedicationView(onAdd: {
                    // Close the sheet after adding
                    showingAddSheet = false
                })
                    .environmentObject(store)
                    .navigationBarItems(leading: Button("Cancel") {
                        showingAddSheet = false
                    })
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
    @State private var isHovering = false
    @State private var showGreenGlow = false
    
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
                return "Missed"
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
    
    // Get gradient for button stroke
    private var buttonStrokeStyle: AnyShapeStyle {
        if wasTakenToday {
            return Color.green.opacity(0.3).anyShapeStyle()
        } else {
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.5),
                    Color.white.opacity(0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ).anyShapeStyle()
        }
    }

    var body: some View {
        let mainContent = VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(medication.name)
                        .font(.system(size: horizontalSizeClass == .regular ? 20 : 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                    
                    Text("\(medication.dosage) - \(medication.frequency)")
                        .font(.system(size: horizontalSizeClass == .regular ? 15 : 14))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                // Time indicator with status
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(timeStatus)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(timeStatusColor)
                        
                        Circle()
                            .fill(timeStatusColor)
                            .frame(width: 6, height: 6)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(timeStatusColor.opacity(0.15))
                    )
                    
                    Text("\(medication.timeToTake, style: .time)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            // Divider line
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.15), .white.opacity(0.05), .white.opacity(0.15)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
            
            // Second row with notes and buttons
            HStack(alignment: .center) {
                if let notes = medication.notes, !notes.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "note.text")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text(notes)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                } else {
                    Spacer()
                }
                
                Spacer()
                
                // Edit button with improved visual
                Button {
                    onEditTap()
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: horizontalSizeClass == .regular ? 20 : 18))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(8)
                        .contentShape(Circle())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel("Edit \(medication.name)")
                
                // Take medication button with enhanced visual feedback
                let takenText = wasTakenToday ? "Taken" : "Take"
                
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isPressed = true
                        
                        // Reset the press state after a short delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            isPressed = false
                            
                            // Only show the green glow effect if the medication wasn't already taken
                            if !wasTakenToday {
                                // Trigger the green glow effect
                                withAnimation(.easeInOut(duration: 0.6)) {
                                    showGreenGlow = true
                                }
                                
                                // Reset the glow after a while
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    withAnimation(.easeOut(duration: 0.8)) {
                                        showGreenGlow = false
                                    }
                                }
                            }
                            
                            onLogTap()
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: wasTakenToday ? "checkmark.circle.fill" : "circle.dotted")
                            .font(.system(size: horizontalSizeClass == .regular ? 22 : 18, weight: .semibold))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(wasTakenToday ? Color.green : Color.white.opacity(0.9))
                        
                        Text(takenText)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(wasTakenToday ? Color.green : Color.white.opacity(0.9))
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(
                        Capsule()
                            .fill(wasTakenToday ? Color.green.opacity(0.2) : Color.white.opacity(0.1))
                            .overlay(
                                Capsule()
                                    .stroke(buttonStrokeStyle, lineWidth: 1)
                            )
                    )
                    .scaleEffect(isPressed ? 0.95 : 1)
                }
                .buttonStyle(ScaleButtonStyle())
                .contentShape(Capsule())
                .accessibilityLabel(wasTakenToday ? "\(medication.name) already taken today" : "Take \(medication.name)")
            }
        }
        .padding(16)
        
        // Create the final view with all the modifiers
        return mainContent
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial.opacity(isHovering ? 0.6 : 0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.5),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.green, lineWidth: showGreenGlow ? 2 : 0)
                    .shadow(color: Color.green.opacity(showGreenGlow ? 0.7 : 0), radius: 8, x: 0, y: 0)
                    .scaleEffect(showGreenGlow ? 1.03 : 1)
            )
            .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
            .shadow(color: Color.green.opacity(showGreenGlow ? 0.5 : 0), radius: 15, x: 0, y: 0)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovering = hovering
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(medication.name), \(medication.dosage), \(medication.frequency), \(formatTimeAccessible(medication.timeToTake))")
            .accessibilityHint(wasTakenToday ? "Already taken today" : "Double tap to log as taken")
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
