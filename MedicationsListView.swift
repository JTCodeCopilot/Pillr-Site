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
            return Color(hex: "#D9B382")
        } else {
            return .blue
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top section with name and time
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(medication.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hex: "#C7C7BD"))
                    
                    Text("\(medication.dosage) - \(medication.frequency)")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(timeStatus)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(timeStatusColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(timeStatusColor.opacity(0.15))
                            .cornerRadius(12)
                        
                        Image(systemName: "bell.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                    }
                    
                    Text("\(medication.timeToTake, style: .time)")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Color(hex: "#C7C7BD"))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            // Notes section if available
            if let notes = medication.notes, !notes.isEmpty {
                HStack {
                    Text(notes)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            
            // Divider
            Rectangle()
                .fill(Color(hex: "#C7C7BD").opacity(0.1))
                .frame(height: 1)
            
            // Action buttons
            HStack(spacing: 0) {
                // Edit button
                Button(action: onEditTap) {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil")
                            .font(.system(size: 14))
                        Text("Edit")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                
                // Vertical divider
                Rectangle()
                    .fill(Color(hex: "#C7C7BD").opacity(0.1))
                    .frame(width: 1, height: 32)
                
                // Take/Taken button
                Button(action: onLogTap) {
                    HStack(spacing: 6) {
                        Image(systemName: wasTakenToday ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 14))
                        Text(wasTakenToday ? "Taken" : "Take")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(wasTakenToday ? Color(hex: "#D9B382") : Color(hex: "#C7C7BD"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            }
        }
        .background(Color.black.opacity(0.35))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    wasTakenToday ? Color(hex: "#D9B382").opacity(0.3) : Color(hex: "#C7C7BD").opacity(0.1),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
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

#if DEBUG
struct MedicationsListView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a lightweight preview
        let previewStore = MedicationStore.previewStore()
        let previewSettings = UserSettings.previewSettings()
        
        MedicationsListView()
            .environmentObject(previewStore)
            .environmentObject(previewSettings)
            .background(Color(hex: "#404C42"))
            .preferredColorScheme(.dark)
            .previewDisplayName("MedicationsListView")
    }
}
#endif 