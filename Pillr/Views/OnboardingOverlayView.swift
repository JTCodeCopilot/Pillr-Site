//
//  OnboardingOverlayView.swift
//  Pillr
//
//  Created by Codex on 2025-XX-XX.
//

import SwiftUI

enum OnboardingIcon {
    case system(name: String)
    case asset(name: String)
}

struct OnboardingStageInfo {
    let title: String
    let description: AnyView
    let benefits: [String]
    let icon: OnboardingIcon
    let accentColor: Color
    let buttonAccessibilityLabel: String
    let subtitle: String?
    let buttonTitle: String
    let verticalOffset: CGFloat

    init(
        title: String,
        description: AnyView,
        benefits: [String],
        icon: OnboardingIcon,
        accentColor: Color,
        buttonAccessibilityLabel: String,
        subtitle: String? = nil,
        buttonTitle: String = "Done",
        verticalOffset: CGFloat = 0
    ) {
        self.title = title
        self.description = description
        self.benefits = benefits
        self.icon = icon
        self.accentColor = accentColor
        self.buttonAccessibilityLabel = buttonAccessibilityLabel
        self.subtitle = subtitle
        self.buttonTitle = buttonTitle
        self.verticalOffset = verticalOffset
    }
}

struct OnboardingOverlayView: View {
    let info: OnboardingStageInfo
    let onDismiss: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.72)
                    .ignoresSafeArea()

                VStack {
                    Spacer()

                    OnboardingCardView(info: info, onDismiss: onDismiss)
                        .offset(y: info.verticalOffset)
                        .padding(.horizontal, 16)
                        .padding(.bottom, geometry.safeAreaInsets.bottom + 16)
                }
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .bottom)
            }
        }
    }
}

struct OnboardingCardView: View {
    let info: OnboardingStageInfo
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 10) {
                iconContent

                Text(info.title)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                if let subtitle = info.subtitle {
                    Text(subtitle)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.top, 2)
                }
            }

            VStack(alignment: .leading, spacing: 16) {
                info.description
                    .foregroundColor(Color.white.opacity(0.85))
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .environment(\.multilineTextAlignment, .leading)
                    .frame(maxWidth: 420, alignment: .leading)

                if !info.benefits.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(info.benefits, id: \.self) { benefit in
                            HStack(alignment: .top, spacing: 10) {
                                Circle()
                                    .fill(info.accentColor)
                                    .frame(width: 9, height: 9)
                                    .padding(.top, 5)

                                Text(benefit)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundColor(Color.white.opacity(0.9))
                                    .multilineTextAlignment(.leading)
                            }
                        }
                    }
                    .frame(maxWidth: 420, alignment: .leading)
                }
            }

            Button(action: onDismiss) {
                Text(info.buttonTitle)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: "#404C42"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white)
                            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.8), lineWidth: 0.5)
                            )
                    )
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(info.buttonAccessibilityLabel)
        }
        .padding(.all, 28)
        .frame(maxWidth: 460)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color(hex: "#2A2D28").opacity(0.98))
                .shadow(color: Color.black.opacity(0.4), radius: 16, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var iconContent: some View {
        switch info.icon {
        case .system(let name):
            Image(systemName: name)
                .font(.system(size: 64, weight: .semibold))
                .foregroundColor(.white)
        case .asset(let name):
            Image(name)
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
        }
    }
}
