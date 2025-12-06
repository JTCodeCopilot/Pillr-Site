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
        wasMedicationTakenToday(medication, logs: store.logs)
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
            return Color(hex: "#F5F5F5")
        } else {
            return .blue
        }
    }

    private var cardCornerRadius: CGFloat {
        wasTakenToday ? 20 : 12
    }

    private var cardTopPadding: CGFloat {
        wasTakenToday ? 12 : 16
    }

    private var cardHorizontalPadding: CGFloat {
        wasTakenToday ? 22 : 16
    }

    private var cardBackgroundColor: Color {
        wasTakenToday ? Color.black.opacity(0.45) : Color.black.opacity(0.35)
    }

    private var cardShadowColor: Color {
        wasTakenToday ? Color.black.opacity(0.28) : Color.black.opacity(0.15)
    }

    private var cardShadowRadius: CGFloat {
        wasTakenToday ? 10 : 4
    }

    private var cardShadowYOffset: CGFloat {
        wasTakenToday ? 6 : 2
    }

    private var titleFont: Font {
        wasTakenToday ? .system(size: 20, weight: .semibold) : .system(size: 18, weight: .semibold)
    }

    private var titleColor: Color {
        wasTakenToday ? Color(hex: "#F5F5F5") : Color(hex: "#C7C7BD")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top section with name and time
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(medication.name)
                        .font(titleFont)
                        .foregroundColor(titleColor)
                        .accessibilityAddTraits(.isHeader)
                    
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
                            .accessibilityLabel("Reminder set")
                    }
                    
                    Text("\(medication.timeToTake, style: .time)")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Color(hex: "#C7C7BD"))
                }
            }
            .padding(.horizontal, cardHorizontalPadding)
            .padding(.top, cardTopPadding)
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
                .padding(.horizontal, cardHorizontalPadding)
                .padding(.bottom, 12)
                .accessibilityLabel("Notes: \(notes)")
            }
            
            // Divider
            Rectangle()
                .fill(Color(hex: "#C7C7BD").opacity(0.1))
                .frame(height: 1)
                .accessibilityHidden(true)
            
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
                .accessibilityLabel("Edit \(medication.name)")
                
                // Vertical divider
                Rectangle()
                    .fill(Color(hex: "#C7C7BD").opacity(0.1))
                    .frame(width: 1, height: 32)
                    .accessibilityHidden(true)
                
                // Take/Taken button
                Button(action: onLogTap) {
                    HStack(spacing: 6) {
                        Image(systemName: wasTakenToday ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 14))
                        Text(wasTakenToday ? "Taken" : "Take")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(wasTakenToday ? Color(hex: "#F5F5F5") : Color(hex: "#C7C7BD"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .accessibilityLabel(wasTakenToday ? "\(medication.name) already taken today" : "Mark \(medication.name) as taken")
                .accessibilityHint(wasTakenToday ? "Double tap to view log details" : "Double tap to record medication as taken")
                .disabled(wasTakenToday)
            }
            .padding(.horizontal, cardHorizontalPadding)
        }
        .background(cardBackgroundColor)
        .cornerRadius(cardCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: cardCornerRadius)
                .stroke(
                    wasTakenToday ? Color(hex: "#F5F5F5").opacity(0.3) : Color(hex: "#C7C7BD").opacity(0.1),
                    lineWidth: 1
                )
        )
        .shadow(color: cardShadowColor, radius: cardShadowRadius, x: 0, y: cardShadowYOffset)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(medication.name), \(medication.dosage), \(medication.frequency), \(formatTimeAccessible(medication.timeToTake))")
        .accessibilityValue(wasTakenToday ? "Already taken today" : timeStatus)
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
