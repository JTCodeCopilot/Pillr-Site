import SwiftUI

enum CloudSyncChoice {
    case onDeviceOnly
    case connect
}

struct CloudSyncChoiceOverlay: View {
    let onChoice: (CloudSyncChoice) -> Void

    @State private var selectedChoice: CloudSyncChoice?
    @State private var showFinalConfirmation = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
                    .overlay(
                        Color.black.opacity(0.58)
                            .ignoresSafeArea()
                    )

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .center, spacing: 8) {
                            Image("PillrLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 68, height: 68)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 3)

                            Text("Welcome to Pillr.")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundColor(Color(hex: "#F5F7F4"))
                                .multilineTextAlignment(.center)

                        Text("Let’s start by choosing how your information will be stored.")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(Color(hex: "#E0E7DC").opacity(0.92))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)

                        VStack(spacing: 14) {
                        MyMedsSyncChoiceCard(
                            title: "On this device only",
                            detail: "Everything stays local on this iPhone. No cloud backup or sync.",
                            benefits: [
                                "Stored only on this iPhone",
                                "No cloud syncing between devices",
                                "You can switch to iCloud later in Settings"
                            ],
                            isPrimary: false,
                            isSelected: selectedChoice == .onDeviceOnly,
                            isMuted: selectedChoice != nil && selectedChoice != .onDeviceOnly,
                            action: { selectedChoice = .onDeviceOnly }
                        )

                        MyMedsSyncChoiceCard(
                            title: "Use iCloud Sync",
                            detail: "Back up and sync across your Apple devices. Recommended for continuity.",
                            benefits: [
                                "Encrypted backup in your iCloud account",
                                "Syncs across iPhone, iPad, and Mac",
                                "Easier recovery when changing devices"
                            ],
                            isPrimary: true,
                            isSelected: selectedChoice == .connect,
                            isMuted: selectedChoice != nil && selectedChoice != .connect,
                            action: { selectedChoice = .connect }
                        )
                        }

                        Button {
                            showFinalConfirmation = true
                        } label: {
                            Text("Continue")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundColor(Color(hex: "#F5F7F4").opacity(selectedChoice == nil ? 0.56 : 1.0))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color(hex: "#5B695D").opacity(selectedChoice == nil ? 0.56 : 1.0))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(selectedChoice == nil)
                        .shadow(color: Color.black.opacity(0.22), radius: 12, x: 0, y: 6)

                        Text("Select one option, then continue")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(Color(hex: "#E0E7DC").opacity(0.78))
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 22)
                }
                .frame(maxWidth: 560)
                .frame(maxHeight: min(geometry.size.height * 0.9, 760))
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color(hex: "#404C42"))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.11), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.4), radius: 24, x: 0, y: 10)
                .padding(.horizontal, 18)
                .offset(y: -22)
            }
        }
        .alert("Confirm selection?", isPresented: $showFinalConfirmation) {
            Button(confirmButtonTitle, role: .none) {
                guard let selectedChoice else { return }
                onChoice(selectedChoice)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(confirmMessage)
        }
    }

    private var confirmButtonTitle: String {
        switch selectedChoice {
        case .onDeviceOnly:
            return "Yes, keep local"
        case .connect:
            return "Yes, use iCloud"
        case .none:
            return "Confirm"
        }
    }

    private var confirmMessage: String {
        switch selectedChoice {
        case .onDeviceOnly:
            return "Medication data will stay only on this device until you change it in Settings."
        case .connect:
            return "Medication data will sync with iCloud across your Apple devices."
        case .none:
            return ""
        }
    }
}

private struct MyMedsSyncChoiceCard: View {
    let title: String
    let detail: String
    let benefits: [String]
    let isPrimary: Bool
    let isSelected: Bool
    let isMuted: Bool
    let action: () -> Void

    private var leadingIconName: String {
        isPrimary ? "icloud.and.arrow.up" : "iphone"
    }

    private var cardColor: Color {
        if isPrimary {
            return Color(hex: "#A7B3A2").opacity(0.76)
        }
        return Color(hex: "#5B695D").opacity(0.96)
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: leadingIconName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "#F5F7F4").opacity(0.9))
                        .padding(.top, 6)

                    Text(title)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(hex: "#F5F7F4"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.92)

                    Spacer()

                    Circle()
                        .fill(isSelected ? Color.white.opacity(0.3) : Color.white.opacity(0.08))
                        .frame(width: 30, height: 30)
                        .overlay {
                            Image(systemName: isSelected ? "checkmark" : "circle")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color(hex: "#F5F7F4").opacity(isSelected ? 1 : 0.65))
                        }
                }

                Text(detail)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: "#E0E7DC").opacity(0.94))
                    .multilineTextAlignment(.leading)
                    .lineSpacing(3)

                VStack(alignment: .leading, spacing: 7) {
                    ForEach(benefits, id: \.self) { benefit in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(Color(hex: "#F5F7F4").opacity(0.8))
                                .frame(width: 5, height: 5)
                                .padding(.top, 7)

                            Text(benefit)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(Color(hex: "#E0E7DC").opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardColor)
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        isSelected ? Color.white.opacity(0.45) : Color.white.opacity(0.1),
                        lineWidth: isSelected ? 1.6 : 1
                    )
            )
            .shadow(color: Color.black.opacity(0.24), radius: 13, x: 0, y: 7)
            .shadow(color: Color.black.opacity(0.12), radius: 5, x: 0, y: 2)
            .opacity(isMuted ? 0.52 : 1.0)
            .scaleEffect(isSelected ? 1.0 : 0.985)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isMuted)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}
